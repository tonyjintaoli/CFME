class Api::HostController < ApplicationController

  before_filter :check_privileges
  after_filter :cleanup_action

  def index
      @hosts = Host.all
      respond_to do |format|
         format.json { render json: @hosts }
         format.xml { render xml: @hosts }
      end
  end

  private ####

end

