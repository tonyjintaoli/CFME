class Api::VmController < ApplicationController

  before_filter :check_privileges
  after_filter :cleanup_action

  def index
      session[:vm_type] = nil
      @vms = Vm.all
      respond_to do |format|
         format.json { render json: @vms }
         format.xml { render xml: @vms }
      end
  end

  private ####

end

