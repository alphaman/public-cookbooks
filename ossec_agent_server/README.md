### Supported operating systems:
- Debian 7 (wheezy)
- Debian 8 (jessie)
- Ubuntu 12.04 (precise)
- Ubuntu 14.04 (trysty)
- Centos 5
- Centos 6
- Red Hat Enterprise Linux 5
- Red Hat Enterprise Linux 6
- Amazon Linux 2015.03

### Install the cookbook on your chef server

To install the ossec_agent_server cookbook follow the next steps:</br>
1. ```git clone https://github.com/cloudaware/public-cookbooks```</br>
2. ```cp -a public-cookbooks/ossec_agent_server /var/chef/cookbooks```</br>
3. ```knife cookbook upload ossec_agent_server```</br>
4. ```rm -fr public-cookbooks```</br>

### Create role

Create a role named ossec_agent containing this cookbook, this can be done easily using the chef web interface under the roles section(Under Policy -> Roles push Create and assign the cookbook)

### Create databag

Create a databag that will contain the server hostname using the next commands:</br>
```knife data bag create ossec```</br>
```echo "{\"id\":\"user\", \"agent_server_hostname\":\"ServerName\"}" > ossec.json```</br>
```knife data bag from file ossec ossec.json```</br>
```rm -f ossec.json```</br>

Where ```ServerName``` is the actual hostname of the server

### Add role to nodes 

Add the ossec_agent role to the nodes that need ossec installed using the chef web interface. To do this take the following steps:</br>
1. Go to ```Nodes```</br>
2. Select the node</br>
3. Under ```Run List``` press Edit</br>
4. Add the ```ossec_agent``` role to the Current Run List from Available Roles</br>
5. Press ```Save Run List```
