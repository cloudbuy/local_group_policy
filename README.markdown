# Puppet Local Group Policy (Windows)

create by Paul Cannon at email paulscannon at gmail dot com 

## Local_security_policy features

If you want to leave the options as default, please do not fill in.  The module will pull the default value from microsoft standards.


This module uses types and providers to list, update, validate settings

## Use
The title and name of the resources is exact match of what is in secedit GUI.  If you are uncertain of the setting name and values just user 'resource' to pipe them all into a file and make adjustments as necessary.
The block will look like this.  For some values this will be actual value and not human readable value.  For instance: If GPO has a value of "3 - Tuesday", the actual value is likely 3.
```
local_group_policy { 'Specify intranet Microsoft update service location': <- Name exactly like the GPO
   ensure = > 'present',    <- Always present
   policy_settings => {     <- This is an area with the options listed in the group policy editor 
      'Set the intranet statistics server:' => 'https://demo.host.com',    
      'Set the intranet update service for detecting updates:' => 'https://demo.host.com',  
   }
}
```


### Listing all settings
Show all local_group_policy resources available on server.  Note this will only list the policies that are currently set and not the X number of thousand policies that Microsoft makes available.
```
puppet resource local_group_policy
```
Show a single local_security_policy resources available on server. Currently this most be something already set on the server.   I am working on providing the defaults back for any setting
```
puppet resource local_security_policy 'Specify intranet Microsoft update service location'


```

### More examples

