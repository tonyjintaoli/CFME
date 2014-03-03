class Api::SessionsController < ApplicationController

  def index
      redirect_to :action => 'create'
  end

  def create
    log_prefix = "API(login)"
    # $log.info("#{log_prefix} User: #{params}")
    if params[:format] == "xml"
       xml = REXML::Document.new(request.raw_post)
       #$log.info("#{log_prefix} User: #{xml.elements["/userintenant/userName"].text.strip}")
       #$log.info("#{log_prefix} Password: #{xml.elements["/userintenant/password"].text.strip}")
       user = {
          :name             =>  xml.elements["/userintenant/userName"].text.strip,
          :password         =>  xml.elements["/userintenant/password"].text.strip,
       }
    end

    url = validate_user(user)

    unless @wait_for_task
      if url  # User is logged in
          $log.info("#{log_prefix} User: #{session[:userid]}")
      else    # No URL, show error msg
          session.clear
      end
      respond_to do |format|
	format.xml { render xml: session.to_xml(:root => 'user') }
      end
    end
  end

  # Methods to handle login/authenticate/logout functions

  def logout
      log_prefix = "API(logout)"
      $log.info("#{log_prefix} User: #{session}")
      s = session[:userid]
      user = User.find_by_userid(s)
      user.logoff if user
      session.clear
      respond_to do |format|
        format.xml { render xml: session.to_xml(:root => 'user') }
      end
  end

  private ###########################

  # Validate user login credentials - return <url for redirect> or nil if an error
  def validate_user(user)
    unless params[:task_id]                       # First time thru, kick off authenticate task

      # Pre_authenticate checks
      if user.blank? || user[:name].blank?
        @flash_msg = "Error: Name is required"
        return nil
      end
      if user[:new_password] != nil && user[:new_password] != user[:verify_password]
        @flash_msg = "Error: New password and verify password must be the same"
        return nil
      end
      if user[:new_password] != nil && user[:new_password].blank?
        @flash_msg = "Error: New password can not be blank"
        return nil
      end
      if user[:new_password] != nil && user[:password] == user[:new_password]
        @flash_msg = "Error: New password is the same as existing password"
        return nil
      end

      # Call the authentication, use wait_for_task if a task is spawned
      begin
        user_or_taskid = User.authenticate(user[:name],user[:password])
      rescue MiqException::MiqEVMLoginError => err
        @flash_msg = I18n.t("flash.authentication.error")
        user[:name] = nil
        return
      end
      if user_or_taskid.kind_of?(User)
        user[:name] = user_or_taskid.userid
      else
        wait_for_task({:task_id=>user_or_taskid})           # Wait for the task to complete
        @wait_for_task = true
        return
      end
    else
      task = MiqTask.find_by_id(params[:task_id])
      if task.status.downcase != "ok"
        @flash_msg = "Error: " + task.message
        task.destroy
        return
      end
      user[:name] = task.userid
      task.destroy
    end

    if user[:name]
      if user[:new_password] != nil
        begin
          User.find_by_userid(user[:name]).change_password(user[:password], user[:new_password])
        rescue StandardError => bang
          @flash_msg = "Error: " + bang.message
          return nil
        end
      end

      db_user = User.find_by_userid(user[:name])

      start_url = session[:start_url] # Hang on to the initial start URL
      session_reset(db_user)          # Reset/recreate the session hash

      # If license is not valid, only allow super admins in
      if session[:userrole] != 'super_administrator' &&
        ! MiqLicense.valid?
        @flash_msg = "Product license is invalid, please contact the System Administrator"
        return nil
      end

      # If a main db is specified, don't allow logins until super admin has set up the system
      if session[:userrole] != 'super_administrator' &&
        get_vmdb_config[:product][:maindb] &&
          ! Vm.first &&
          ! Host.first
        @flash_msg = "The system has not been configured, please contact the administrator"
        return nil
      end

      session_init(db_user)    # Initialize the session hash variables

      # If invalid license, send super_admin to the support screens
      if session[:userrole] == 'super_administrator' &&
        ! MiqLicense.valid?
        return url_for(:controller=>"ops")
      end

      if MiqServer.my_server(true).logon_status != :ready
        if session[:userrole] == 'super_administrator'
          return url_for(:controller=>"ops",
                        :action=>'explorer',
                        :flash_warning=>true,
                        :no_refresh=>true,
                        :flash_msg=>I18n.t("flash.server_still_starting_admin"),
                        :escape=>false)
        else
          @flash_msg = I18n.t("flash.server_still_starting")
          return nil
        end
      end

      # Start super admin at the main db if the main db has no records yet
      if session[:userrole] == 'super_administrator' &&
        get_vmdb_config[:product][:maindb] && !get_vmdb_config[:product][:maindb].constantize.first
        if get_vmdb_config[:product][:maindb] == "Host"
          return url_for(:controller=>"Host",
                        :action=>'show_list',
                        :flash_warning=>true,
                        :flash_msg=>I18n.t("flash.no_host_defined"))
        elsif get_vmdb_config[:product][:maindb] == "EmsInfra"
          return url_for(:controller=>"ems_infra",
                        :action=>'show_list',
                        :flash_warning=>true,
                        :flash_msg=>I18n.t("flash.no_vc_defined"))
        end
      end

      if start_url == nil
        if @settings[:display][:startpage] # if default startpage is set, check if it is allowed
          MiqShortcut.start_pages.each do |sp|
            area, typ = sp[1].split("/")
            if @settings[:display][:startpage] == sp[0] && role_allows(:feature=>sp[2], :any=>true)
              @settings[:display][:startpage] = sp[0]
              @set_page = true
            end
          end
          if !@set_page   # set the first one in START_PAGES to be default page
            MiqShortcut.start_pages.each do |sp|
              area, typ = sp[1].split("/")
              if role_allows(:feature=>sp[2], :any=>true)
                @settings[:display][:startpage] = sp[0]
                break
              end
            end
          end
          return @settings[:display][:startpage]
        else
          return url_for(:action=>"show")
        end
      else  # if a url was saved when the session was started, go there
        return url_for(start_url)
      end
    end

    session[:userid], session[:username], session[:user_tags] = nil
    User.current_userid = nil
    @flash_msg ||= "Error: Authentication failed"
    return nil
  end

  # Reset and set the user vars in the session object
  def session_reset(db_user)  # User record
    # Clear session hash just to be sure nothing is left (but copy over some fields)
    winh = session[:winH]
    winw = session[:winW]
    session.clear
    session[:winH] = winh
    session[:winW] = winw

    session[:userid] = db_user.userid

    # Set the current userid in the User class for this thread for models to use
    User.current_userid = session[:userid]

    session[:username] = db_user.name

    # set group and role ids
    session[:group] = db_user.miq_group.id              # Set the user's group id
    session[:group_description] = db_user.miq_group.description # and description
    role = db_user.miq_group.miq_user_role
    session[:role] = role.id                            # Set the group's role id

    # Build pre-sprint 69 role name if this is an EvmRole read_only role
    session[:userrole] = role.read_only? ? role.name.split("-").last : ""

    # Save an array of groups this user is eligible for, if more than 1
    eg = db_user.eligible_miq_groups.sort{|a,b| a.description.downcase <=> b.description.downcase}
    session[:eligible_groups] = db_user.nil? || eg.length < 2 ?
        [] :
        eg.collect{|g| [g.description, g.id]}

    # Clear instance vars that end up in the session
    @sb = @edit = @view = @settings = @lastaction = @perf_options = @assign =
        @current_page = @search_text = @detail_sortcol = @detail_sortdir =
            @exp_key = @server_options = @tl_options =
                @pp_choices = @panels = @breadcrumbs = nil
  end

  # Initialize session hash variables for the logged in user
  def session_init(db_user)
    session[:user_tags] = db_user.tag_list unless db_user == nil      # Get user's tags

    # Load settings for this user, if they exist
    @settings = copy_hash(DEFAULT_SETTINGS)             # Start with defaults
    unless db_user == nil || db_user.settings == nil    # If the user has saved settings

      db_user.settings.delete(:dashboard)               # Remove pre-v4 dashboard settings
      db_user.settings.delete(:db_item_min)

      @settings.each { |key, value| value.merge!(db_user.settings[key]) unless db_user.settings[key] == nil }
      @settings[:col_widths] = db_user.settings[:col_widths]  # Get the user's column widths
      @settings[:default_search] = db_user.settings[:default_search]  # Get the user's default search setting
    end

    # Copy ALL display settings into the :css hash so we can easily add new settings
    @settings[:css] ||= Hash.new
    @settings[:css].merge!(@settings[:display])
    @settings[:display][:theme] = THEMES.first.last unless THEMES.collect{|t| t.last}.include?(@settings[:display][:theme])
    @settings[:css].merge!(THEME_CSS_SETTINGS[@settings[:display][:theme]])
    if db_user != nil && @settings[:views][:treesize].to_i == 16
      @settings[:views][:treesize] = @settings[:views][:treesize].to_i == 16 ? 20 : @settings[:views][:treesize]
      db_user.settings[:views][:treesize] = @settings[:views][:treesize]
      db_user.save
    end

    @css ||= Hash.new
    @css.merge!(@settings[:display])
    @css.merge!(THEME_CSS_SETTINGS[@settings[:display][:theme]])

    session[:user_TZO] = params[:user_TZO] ? params[:user_TZO].to_i : nil     # Grab the timezone (future use)
    session[:browser] ||= Hash.new("Unknown")
    session[:browser][:name] = params[:browser_name] if params[:browser_name]
    session[:browser][:version] = params[:browser_version] if params[:browser_version]
    session[:browser][:os] = params[:browser_os] if params[:browser_os]
  end

  def get_session_data
    if request.parameters["action"] == "window_sizes" # Don't change layout when window size changes
      @layout = session[:layout]
    else
      @layout = ["my_tasks","timeline","my_ui_tasks"].include?(session[:layout]) ? session[:layout] : "dashboard"
    end
    @report = session[:report]
    @current_page = session[:vm_current_page] # current page number
  end

  def set_session_data
    session[:layout] = @layout
    session[:report] = @report
    session[:vm_current_page] = @current_page
  end

end
