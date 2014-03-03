class Api::VmController < VmController
#ApplicationController

  before_filter :check_privileges
  after_filter :cleanup_action

  def index
      session[:vm_type] = nil
      @vms = Vm.all
      respond_to do |format|
         format.json { render json: @vms }
         format.xml { render xml: @vms.to_xml(:root => 'vms') }
      end
  end

  def show
      @record = Vm.find_by_id(params[:id])
      respond_to do |format|
         format.json { render json: @record }
         format.xml { render xml: @record.to_xml(:root => 'vm') }
      end
  end

  def poweron
      log_prefix = "API(vm.poweron)"
      @record = Vm.find_by_id(params[:id])
      vms = Array.new
      if @record.power_state == "off" || @record.power_state == "suspended"
         vms.push(params[:id])
         self.send("process_vms", vms, "start", "start") unless vms.empty?
         respond_to do |format|
           format.json { render json: '{"status":"success","code":""}' }
           format.xml { render xml: "<PowerOnVMResponse><status>success</status><code></code><messages/></PowerOnVMResponse>"}
         end
      else
         #if @record.vendor.downcase == "redhat"
         #end
         respond_to do |format|
           format.json { render json: @record }
           format.xml { render xml: @record.to_xml(:root => 'vm') }
         end
      end
  end

  def poweroff
      log_prefix = "API(vm.poweroff)"
      @record = Vm.find_by_id(params[:id])
      vms = Array.new
      if @record.power_state == "on"
         vms.push(params[:id])
         self.send("process_vms", vms, "stop", "stop") unless vms.empty?
         respond_to do |format|
           format.json { render json: '{"status":"success","code":""}' }
           format.xml { render xml: "<PowerOffVMResponse><status>success</status><code></code><messages/></PowerOffVMResponse>"}
         end
      else
         respond_to do |format|
                 format.json { render json: @record }
                 format.xml { render xml: @record.to_xml(:root => 'vm') }
         end
      end
  end

  def shutdown
      log_prefix = "API(vm.shutdown)"
      @record = Vm.find_by_id(params[:id])
      vms = Array.new
      if @record.power_state == "on"
         vms.push(params[:id])
         self.send("process_vms", vms, "shutdown_guest", "shutdown") unless vms.empty?
         respond_to do |format|
           format.json { render json: '{"status":"success","code":""}' }
           format.xml { render xml: "<ShutdownVMResponse><status>success</status><code></code><messages/></ShutdownVMResponse>"}
         end
      else
         respond_to do |format|
                 format.json { render json: @record }
                 format.xml { render xml: @record.to_xml(:root => 'vm') }
         end
      end
  end 

  def suspend
      log_prefix = "API(vm.suspend)"
      @record = Vm.find_by_id(params[:id])
      vms = Array.new
      if @record.power_state == "on"
         vms.push(params[:id])
         self.send("process_vms", vms, "suspend", "suspend") unless vms.empty?
         respond_to do |format|
           format.json { render json: '{"status":"success","code":""}' }
           format.xml { render xml: "<SuspendVMResponse><status>success</status><code></code><messages/></SuspendVMResponse>"}
         end
      else
         respond_to do |format|
                 format.json { render json: @record }
                 format.xml { render xml: @record.to_xml(:root => 'vm') }
         end
      end
  end

  private ####

end

