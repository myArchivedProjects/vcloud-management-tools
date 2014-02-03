require 'awesome_print'
require 'vcloud-rest/connection'
require 'yaml'
require 'trollop'

# Template name for testing
#  'CI-TEST'
#
#ENV['VCLOUD_REST_DEBUG_LEVEL'] = "DEBUG"
cmdline_args = Trollop::options do
  opt :vapp_template, "VAPP template to use", :type => :string
  opt :vapp_name, "name for the new vapp", :type => :string
  opt :vapp_description, "description of the new vapp", :type => :string
end

cmdline_args.each do |key, value|
  Trollop::die key, "is required"  if value.nil?
end

# load up the credentials from ~/.vcloud-credentials.yaml
credentials = YAML.load_file("#{ENV['HOME']}/.vcloud-credentials.yaml")
# Example yaml contents for the credentials ~/.vcloud-credentials.yaml file
# ---
#host: 'https://api.vcd.portal.cloud.com'
#user: '999.88.AA00d2'
#password: 'whateveryoufancy,really'
#org_name: '99-88-0-ffffff'
#vdc_name: 'ffffffff-ffff-ffff-ffff-ffffffffffff'
#catalog_name: 'VappCatalog'
#api_version: '6.1'

#login and get your session token
vcloud = VCloudClient::Connection.new(credentials['host'],
                                      credentials['user'],
                                      credentials['password'],
                                      credentials['org_name'],
                                      credentials['api_version'])

vcloud.login

# retrieve the list of vcloud organizations this user has access
orgs = vcloud.get_organizations

# retrieve all the objects within this specific organization
org = vcloud.get_organization(orgs[credentials['org_name']])

# retrieve the list of networks within the organization
networks = org[:networks]


# retrieve the list of vdcs within the organization
vdcs = org[:vdcs]
ap vdcs

# retrieve catalog uuid and then the list of all vapps inside that catalog
catalog_uuid = vcloud.get_catalog_id_by_name(org,
                                             credentials['catalog_name'])

# get the catalog item uuid for my VAPP template
# this is not pretty!
# the reason is that the VAPP template uuid required to deploy from template
# is not the the uuid for that catalog item.
# the item object in the catalog contains a set of children items inside it
# and we require the first :id contained in it.
#
vapp_template_uuid = vcloud.get_catalog_item_by_name(
  catalog_uuid,
  cmdline_args[:vapp_template],
  )[:items][0][:id]

# create a new VAPP called 'vappname1'
vapp = vcloud.create_vapp_from_template(
  credentials['vdc_name'],
  cmdline_args[:vapp_name],
  cmdline_args[:vapp_description],
  vapp_template_uuid,
  false)

ap vapp

# wait until the VAPP is deployed
#vapp_info = vcloud.get_vapp(vapp[:vapp_id])
#ap vapp_info

vcloud.wait_task_completion(vapp[:task_id])


#network_section =  {
  #:name => "test-network",
  #:gateway => "172.16.2.1",
  #:netmask => "255.255.255.0",
  #:start_address => "192.168.0.1",
  #:end_address => "192.168.0.100",
  #:fence_mode => "bridged",
  #:ip_allocation_mode => "POOL",
  #:parent_network =>  vdc[:networks]["Internet-NAT"],
  #:enable_firewall => "false"}

config =  {
  :name => "CI",
  :fence_mode => "bridged",
  :parent_network =>  {
    :id => networks['CI'] },
  :ip_allocation_mode => "POOL" }

network_uuid = networks['CI']

network = vcloud.get_network(network_uuid)

#reconfigure the networks for the vapp
vcloud.add_org_network_to_vapp(vapp[:vapp_id], network, config)



