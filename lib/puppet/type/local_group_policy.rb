Puppet::Type.newtype(:local_group_policy) do
  #confine :operatingsystem => { :windows }
  desc 'Puppet type that models the local group policy'

  ensurable

  newparam(:name, :namevar => true) do
    desc 'Group Policy  Setting Text'
  end

  newproperty(:policy_template) do
    desc 'Group Policy Template Name'
  end

  newproperty(:policy_settings) do
    desc 'Group Policy Settings Text.'
  end
end
