make CloudForms can support Chinese i18n etc,

###

to support Redhat IPA 

you need update and install following gem

gem update -i /opt/rh/ruby193/root/usr/share/gems net-ping
gem uninstall -i /opt/rh/ruby193/root/usr/share/gems net-ping --version 1.5.3
gem update -i /opt/rh/ruby193/root/usr/share/gems net-ldap
gem uninstall -i /opt/rh/ruby193/root/usr/share/gems net-ldap --version 0.2.20110317223538
gem install -i /opt/rh/ruby193/root/usr/share/gems ldap_fluff



