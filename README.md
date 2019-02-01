# Transit Gateway, a walkthrough

This walkthrough shows how to setup Transit Gateway with multiple VPC and Routing domains as well as connect the Transit Gateway to the Datacenter via VPN.

![Speficy Details Screenshot](./images/hybrid-tgw-diagram.png)

## Introduction

When building a multi-VPC and/or multi-account architecture there are several services that we need to consider to provide seamless integration between our AWS environment and the existing infrastrucutre in our datacenter.
Foundationally, we need to provide robust connectivity and routing between the datacenter and all of the VPCs. But we also need to provide and control routing between those VPC. For example we may have a 'Shared Services' VPC that every other VPC needs access to where we place common resources that everyone needs, such as a NAT Gateway Service to access the internet. At the same time, we dont want just any VPC talking to any other VPC. In this case, we don't want our 'Non-Production' VPCs talking to our 'Production' VPCs.

In the past, customers used thrid-party solutions and/or transit VPCs that they build and managed. In order to remove much of that undifferentiated heavy lifting, we will use **AWS Transit Gateway** Service to provide this connectivty and routing. **AWS Transit Gateway** is a service that enables custoemrs to connect their Amazon Virtual Private Clouds(VPCs) and their on-premise networks to a single highly-available gateway. **AWS Transit Gateway** provides easier connectivity, better visibility, more control, and on-demand bandwidth.

After we have connectivity and routing, we need to provide seamless DNS resolution between our Datacenter the VPCs. Our on-prem devices will want to reach out to our resources in the cloud using DNS names, not IP addresses and the resources in the cloud will want to do the same for servers back in our datacenter. Avoiding hard-coding IP addresses in our applications is best practice. To do this we will use **Amazon Route53 Resolver**. **Amazon Route53 Resolver** for hybrid clouds allows us to create highly-available endpoints in our VPCs to integrate with the Amazon Provided DNS (sometmes referred to as the .2 resolver, since it is always 2 addresses up from the VPC CIDR block. i.e. 172.16.0.2 for VPC CIDR 172.16.0.0/24)

## Planning

### VPC layout

![Speficy Details Screenshot](./images/hybrid-vpcs-diagram.png)

There are lots of choices for VPC and Account Architectures, and this is mostly out-of-scope for this workshop. Take a look at what Androski Spicer presented at re:invent 2018 in his [From One to Many: Evolving VPC Design](https://www.youtube.com/watch?v=8K7GZFff_V0 "youtube video") session.
In our case, we are going to provide three types of VPCs:

1. **Non-production VPCs**: We might create several of these to house our training environments, development, and QA resources.
1. **Prodcution VPCs**: This is for our live production systems.
1. **Shared Resources**: For resources and services that we want shared across all VPCs.

Also, we need a VPC to represent our on-premise environment, a simulated datacenter.

1. **Datacenter**: In this workshop we need to simulate a datacenter. In the real world, this would be our existing datacenter or colo and the hardware it contains. But we are going to make our own version in the cloud!

### IP addressing

![Speficy Details Screenshot](./images/hybrid-subnets-diagram.png)

Carving up and assigning private IP address(RFC 1918 addresses) space is big subject and can be daunting of you have a large enterprise today, espeically with mergers. Even when you have a centralized IP address management system (IPAM), you will find undocumented address space being used and sometimes finding useable space is difficult. However we want to find large non-fragmented spaces so we can create a well-summerized network. Don't laugh, we all like a challenge, right?
In our case we found that the 10.0.0.0/11 space was available (I know, fiction, right?). So, we are going to carve up /13's for our production and non-production and we will grab a /16's for our shared service and a /16 for our simulated datacenter.
What does that mean?

1. **Non-Production CIDR: 10.16.0.0/13** is 10.16.0.0 - 10.23.255.255. which we can carve into eight /16 subnets, one for each of our VPCs.
1. **Production CIDR: 10.8.0.0/13** is 10.8.0.0 - 10.15.255.255. which we can also carve into eight /16 subnets.
1. **Shared Service CIDR: 10.0.0.0/16** - 10.0.0.0 - 10.0.255.255. which we will use for 1 Datacenter Services VPC.

\*\*We also will carve out a /16 CIDR for our Datacenter. In the real world this will likely be a list of many summerized CIDRs, both rfc 1918(private address space) and public IP CIDRs (addresses typically assigned to your organization from the Internet Assigned Numbers Authority (IANA) )

- **Simulated Datacenter CIDR: 10.4.0.0/16** - 10.4.0.0 - 10.4.255.255. which will be our Datacenter VPC.

### Connectivity

For connectivity between VPCs, AWS Transit Gateway make life easy. It will form the core of our VPC to VPC and VPC to Datacenter communication.

AWS Transit Gateway is a service that enables customers to connect their Amazon Virtual Private Clouds (VPCs) and their on-premises networks to a single gateway. As you grow the number of workloads running on AWS, you need to be able to scale your networks across multiple accounts and Amazon VPCs to keep up with the growth. Today, you can connect pairs of Amazon VPCs using peering. However, managing point-to-point connectivity across many Amazon VPCs, without the ability to centrally manage the connectivity policies, can be operationally costly and cumbersome. For on-premises connectivity, you need to attach your AWS VPN to each individual Amazon VPC. This solution can be time consuming to build and hard to manage when the number of VPCs grows into the hundreds.

**Key Definitions**

- **attachment** — You can attach a VPC or VPN connection to a transit gateway.

- **transit gateway route table** — A transit gateway has a default route table and can optionally have additional route tables. A route table includes dynamic and static routes that decide the next hop based on the destination IP address of the packet. The target of these routes could be a VPC or a VPN connection. By default, the VPCs and VPN connections that you attach to a transit gateway are associated with the default transit gateway route table.

- **associations** — Each attachment is associated with exactly one route table. Each route table can be associated with zero to many attachments.

- **route propagation** — A VPC or VPN connection can dynamically propagate routes to a transit gateway route table. With a VPC, you must create static routes to send traffic to the transit gateway. With a VPN connection, routes are propagated from the transit gateway to your on-premises router using Border Gateway Protocol (BGP).

![Speficy Details Screenshot](./images/hybrid-tgw-diagram.png)

## Getting Started

First, we need to get our infrastructure in place. The following Cloudformation Template will build out _five_ VPCs. In ourder to do that we will first remove the default VPC. \*note: if you ever remove you default VPC in your own account, you can recreate it via the console or the CLI see the [documentation](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html#create-default-vpc "AWS Default VPC Documentation").

### Pick Region

Since we will be deploying Cloud9 into our Datacenter VPC, we need to pick one of the following Regions:

- N. Virginia (us-east-1)
- Ohio (us-east-2)
- Oregon (us-west-2)
- Ireland (eu-west-1)
- Singapore (ap-southeast-1)

### 1. Delete Default VPC

<details>
<summary>HOW TO Delete Default VPC</summary><p>

1. In the AWS Management Console change to the region you plan to work in and change. This is in the upper right hand drop down menu.

1. In the AWS Management Console choose **Services** then select **VPC**.

1. From the left-hand menu select **Your VPCs**.

1. In the main panel, the checkbox next to only VPC (the default VPC) should be highlighted. You can verify this is the Default VPC by scrolling to the right. The _Default VPC_ column will be maked with **Yes**.

1. With our Default VPC checked select the **Actions** dropdown above it and select **Delete VPC**.

1. In the _Delete VPC_ Panel, check the box 'I Acknowledge that I want to delete my default VPC.' and click the **Delete VPC** button in the bottom right.

1. You should get a green highlighted Dialog stating 'The VPC was deleted' and you can click **Close**. _If it is red, then likely something is deployed into this VPC and you will have to remove those resources (could be EC2 instances, NAT Gateway, VPC endpoints, etc). You could also consider another region from the list above._

</p>
</details>

### 2. Deploy Our Five VPCs

Run CloudFormation template 1.tgw-vpcs.yaml to deploy the VPCs.

<details>
<summary>HOW TO Deploy the VPCs</summary><p>

1. In the AWS Management Console change to the region you are working in. This is in the upper right hand drop down menu.

1. In the AWS Management Console choose **Services** then select **CloudFormation**.

1. In the main panel select **Create Stack** in the upper right hand corner.<p>
   ![Create Stack button](./images/createStack.png)

1. Make sure **Template is ready** is selected from Prepare teplate options.

1. At the **Prerequisite - Prepare template** screen, for **template source** select **Upload a template file** and click **Choose file** from **Upload a Template file**. from your local files select **1.tgw-vpcs.yaml** and click **Open**.

1. Back at the **Prerequisite - Prepare template** screen, clcik **Next** in the lower right.

1. For the **Specify stack details** give the stack a name (be sure to record this, as you will need it later) and Select two Availability Zones (AZs) to deploy to. \*We will be deploying all of the VPCs in the same AZs, but that is not required. Click **Next**.
   ![Stack Parameters](./images/createStack-VPCparameters.png)

1. For **Configuration stack options** we dont need to change anything, so just click **Next** in the bottom right.

1. Scroll down to the bottom of the **Review name_of_youstack** and check the **I acknowledge that AWS CloudFormation might create IAM resources with custom names.** Click the **Create** button in the lower right.
   ![Create Stack](./images/createStack-VPCiam.png)

1. wait for the Stack to show **Create_Complete**.
   ![Stack Complete](./images/createStack-VPCComplete.png)

      </p>
      </details>

<details>
<summary>Investigate the VPCs</summary><p>

- Add steps to take a look at the Subnets, route tables, etc.
- Add steps for using session manager to access an EC2 instance. Talk about no Bastion etc.

</p>
</details>

### 3. Create Transit Gateway and Datacenter Router

We now are ready to start our connectivity and routing policy.
Run Cloudformation template 2.tgw-csr.yaml to deploy the Transit Gateway, route Tables, and the Datacenter Router (Cisco CSR).

<details>
<summary>HOW TO Deploy the Transit Gateway and Datacenter Router</summary><p>

1. In the AWS Management Console change to the region you are working in. This is in the upper right hand drop down menu.

1. In the AWS Management Console choose **Services** then select **EC2**.

1. From the left-hand menu select **Key Pairs**.

1. Click **Create Key Pair** in the main panel and give your new key a name. Click **Create**.

1. Save the keypair to your local machine for easy access later. \*note: We will need this key to access the Cisco CSR router that is in our Simulated Datacenter VPC\*\*.

1. In the AWS Management Console choose **Services** then select **Cloudformation**.

1. In the main panel select **Create Stack** in the upper right hand corner.<p>
   ![Create Stack button](./images/createStack.png)

1. Make sure **Template is ready** is selected from Prepare template options.

1. At the **Prerequisite - Prepare template** screen, for **template source** select **Upload a template file** and click **Choose file** from **Upload a Template file**. from your local files select **2.tgw-csr.yaml** and click **Open**.

1. Back at the **Prerequisite - Prepare template** screen, clcik **Next** in the lower right.

1. For the **Specify stack details** give the stack a name (compounded names work well. i.e. if the VPC stack abouve was named **TGW1** name this stack **TGW1-CSR**), pick the keypair you created earlier, and enter the name of your first stack (must be entered exactly to work). Click **Next**.
   ![Stack Parameters](./images/createStack-CSRparameters.png)

1. For **Configuration stack options** we dont need to change anything, so just click **Next** in the bottom right.

1. Scroll down to the bottom of the **Review name_of_youstack** and check the **I acknowledge the AWS CloudFormation might create IAM resourcfes with custom names.** Click the **Create** button in the lower right.
   ![Create Stack](./images/createStack-VPCiam.png)

1. wait for the Stack to show **Create_Complete**.
   ![Stack Complete](./images/createStack-CSRcomplete.png)

      </p>
      </details>

<details>
<summary>Access AWS Cloud9 Environment </summary><p>
- Add steps to take a look at the TGW, TGW route tables, TGW attachments.
- Add steps for accessing Cloud9.
1. In the AWS Management Console change to the region you are working in. This is in the upper right hand drop down menu.

1. In the AWS Management Console choose **Services** then select **Cloud9**.

1.From **Your Environments** page click the \*_Open IDE_ button on the Workshop Environment Box.
![Cloud 9 Environments](./images/cloud9-environments.png)

1. This will bring up the Cloud9 Console and download the github repo to your working folder.

1. From the **file** menu select **Upload Local Files...** and click **Select files** button, navigate to the key file you created earlier. _note: it should have a .pem extension_.
   ![Upload file to Cloud9](./images/cloud9-uploadfile.png)

1. In the main panelclick the + sign and launch a **New Terminal**. This is a bash shell on the Cloud9 Instance

1. move the key to the .ssh folder: mv _key_name_.pem ~/.ssh/.

1. secure the key file: chmod 400 ~/.ssh/_key_name_.pem

1.From another broswer tab, again navigate, Management Console choose **Services** then select **CloudFormation**.

1. From the EC2 Dashboard, select **Exports** in the left hand menu and find the export for ssh to the CSR: DC1-_stack-name_-CSR-VPC and copy the **Export value**
   ![ssh key and ssh to CSR](./images/cloudformation-csrssh.png)

1. Back on the **Cloud9** Browser tab paste this into the bash shell. _note: in the command you will notice the -i reference to the pem file you just copied, this is the private half of the key pair. The public key is on the Cisco CSR_. Answer **yes** to the \*\*Are you sure you want to continue connectiong (yes/no)?

1. you now are connected to the Cisco CSR in the Datacenter VPC. We will be configuring the Cisco CSR.

1. Lets look at the Interfaces by typing a the #prompt: **show ip interface brief** or **sh ip int br** for short. You will see the GigabitEhternet1 which is the interface our ipsec tunnel were traverse.

1. Take a look at the route table on the CSR by typeing at the #prompt: **sh ip route**. You will see S\* 0.0.0.0/0 which is a static default route pointing to the 10.4.0.1 address. This is the local VPC router which will connect the Interface to the Internet Gateway and use an Elastic IP address (its the IP address you used in the SSH command above). This is a one-to-one mapping.

</p>
</details>

<details>
<summary>Setup VPN Between Datacenter and Transit Gateway</summary><p>
Ipsec tunnels can be setup over the internet or over Direct Connect (using a Public Virtual Interface). In this case we are connecting over the public backbone of AWS.
We will create two VPN tunnels from the Transit Gateway and connect them into a single instance of the Cisco CSR in the Datacenter. 
In a real production environment we would setup a second router for redundancy and for added bandwith setup multiple tunnels from each Cisco CSR (or whichever ipsec device you use). Each ipsec tunnel provides up to 1.25Gbps. This is called Equal cost multipath routing. On the AWS side, up to 50 parallel paths are supported. Many vendors support 4-8 ECMP paths, so check with your vendor)

1. In the AWS Management Console change to the region you are working in. This is in the upper right hand drop down menu.

1. In the AWS Management Console choose **Services** then select **VPC**.

1. From the menu on the left, Scroll down and select **Transit Gateway Attachments**.

1. You will see the VPC Attachments listed, but we want to add one to connect our Datacenter. Click the **Create Transit Gateway Attachment** button above the list.

1. Fill out the **Create Transit Gateway Attachment** form.

- **Transit Gateway ID** will have a name Tag matching your first Cloudformation Stack name.
- **Attachment Type** is **VPN**
- **Customer Gateway** (CGW) will be **Exisiting**. _note: the Cloudformation template created the CGW. it is the IP address of our Datacenter VPN device and in the lab matches the IP of the SSH command above._
- Leave **Routing options** set to **Dynamic(requires BGP)**. _note: BGP is required if you want traffic to balance across more than one VPN tunnel at a time (ECMP or Equal Cost Multipathing)_
- For **Inside IP CIDR for Tunnel 1** use **169.254.10.0/30** and **169.254.11.0/30** for CIDR.

- For **Pre-Shared Key for Tunnel 1** use **awsamazon**
- For **Inside IP CIDR for Tunnel 2** use **169.254.10.0/30** and **169.254.11.0/30** for CIDR.
- For **Pre-Shared Key for Tunnel 2** use **awsamazon**
- Once the page is filled out, click **Create attachment** at the bottom right.
  ![Create VPN Attachment](./images/tgw-createvpnattach.png)

1.  While we are on the **Transit Gateway Attachments** page, lets go back to the top and give the VPN connection a name. Scan down the **Resource type** column for the VPN Attachment. \*note: you may have to hit the refresh icon in the upper right above the table to get the new VPN to show. If you click the pencil that appears when you mouse over the **Name** column, you can enter a name. Be sure to click the _check_ mark to save the name.

1.  From the Menu on the Left Select **Site-to-Site VPN Connections**. From the main panel, you likely will see the VPN is in State **pending**. That fine. Lets take a look toward the bottom, and click the **Tunnel Details** tab. Record the two **Outside IP Address**es. We want to record them in the order of the one pairing up with the **Inside IP CIDR** range 169.254.**10**.0/30 first. _note: You can use cloud9 as a sratch pad, by clicking the + in the main panel and selecting **New file**. be sure to paste them in the right order!_

1.  From the Menu on the Left Select **Transit Gateway Route Tables**. From the table in the main panel select **Green Route Table**. Lets take a look toward the bottom, and click the **Associations** tab. Associations mean that traffic coming from the outside toward the Transit gateway will use this route table to know where the packet will go after routing through the TGW. _note: An attachment can only be Associated with one route table. But a route table can have multiple associations_. Here in the **Green Route Table**, We already have one association, The **Datacenter Services VPC**. Click **Create associations** in the **Associations** tab. From the drop-down list, select the vpn. _note:it should be the only one in the list without a **Association route table** ._ Click **Create assocation**.
    ![Associate VPN](./images/tgw-vpnassocationspending.png)

1.  While at the **Transit Gateway Route Tables**, take a look at the **Propagations** tab. These are the Resources that Dynamically inform the route table. An attachment can propigate to multiple route tables. For the Datacenter, we want to propagate to all of the route tables so the VPC asscoicated with each route table can route back to the datacenter. Lets start with the **Green Route Table**. We can see all of the VPCs are propagating their CIDR to the route table. Since the **Datacenter Services VPC** is also associated with this route table, we need to propagate the VPN routes to the **Green Route Table**.

1.  Repeat the above step on the propagations tab for the **Red Route Table** and the **Blue Route Table**.

1.  Take a look at each of the route tables and notice the tab **Routes**. You can see the routes that are propagated, as well as a static route table that was created for you by the Cloudformation template. That's the default route (0.0.0.0/0) that will direct traffic destined for the internet to the **Datacenter Services VPC** and ultimately through the NAT Gateway in that VPC. _note: there is also a route table with no name. This is the dafult route table. In this lab we do not intend to use the default route table_.

1.  Back on the Cloud9 browser tab, using the two VPN tunnel endpoint address generated from the step above, cd to tgwwalk on the Cloud9 bash console and run the bash script, ./createcsr.sh. _note: Be sure to put the address that lines up with Inside IP CIDR address 169.254.10.0/30 for ip1_.
    Example from Site-to-Site VPN
    ![VPN tunnel Addresses](./images/vpn-tunneladdresses.png)

    ```
    cd tgwwalk
    ##./createcsr.sh ip1 ip2 outputfile
    ./createcsr.sh 35.166.118.167 52.36.14.223 mycsrconfig.txt
    ```

    _note: AWS generates starter templates to assist with the configuration for the on-prem router. For your real world deployments, you can get a starter template from the console for various devices (Cisco, Juniper, Palo Alto, F5, Checkpoint, etc). Word of Caution is to look closely at the routing policy in the BGP section. you may not want to send a default route out. You likely also want to consider using a route filter to prevent certain routes from being propagated to you._

1.  On the left hand panel, the output file should be listed. You may have to open the tgwalk folder to see the txt file. Select all text (ctrl-a on pc/command-a on mac). Then copy the text to buffer (Select all text (ctrl-c on pc/command-c on mac))

1.  enter configuration mode, which will take you to a config prompt

    ```
    ip-10-4-0-17#conf t
    Enter configuration commands, one per line.  End with CNTL/Z.
    ip-10-4-0-17(config)#
    ```

1.  Once in Configuration mode _note: you should see (config)# prompt_, paste Select all text (ctrl-v on pc/command-v on mac) in the text from the outputfile created in step 4. This will slowly paste in the configuration file.

1.  if you are still at the (config)# or (config-router) prompt, type **end** and press enter.

1.  Now lets look at the new interfaces: **sh ip int br**. You should see new interfaces: Tunnel1 and Tunnel2 and they both should show up. \*note: if they do not chnage from down to up after a 2 minutes, likely casue is the ip addresses were flipped in the createcsr script.
    ![ssh key and ssh to CSR](./images/csr-showtunnel.png)

1.  Lets make sure we are seeing the routes on the Cisco CSR. first we can look at what BGP is seeing: **show ip bgp summary**. The most important thing to see is the State/PfxRcd (Prefixes received). If this is in Active or Idle (likely if neigbor statement is wrong: IP address, AS number) there is a configuration issue. What we want to see is a number. In fact if everything is setup correctly we should see 4 for each neighbor.

    ```
    ip-10-4-0-17#sh ip bgp summ
    BGP router identifier 169.254.10.2, local AS number 65001
    BGP table version is 6, main routing table version 6
    5 network entries using 1240 bytes of memory
    9 path entries using 1224 bytes of memory
    2/2 BGP path/bestpath attribute entries using 560 bytes of memory
    1 BGP AS-PATH entries using 24 bytes of memory
    0 BGP route-map cache entries using 0 bytes of memory
    0 BGP filter-list cache entries using 0 bytes of memory
    BGP using 3048 total bytes of memory
    BGP activity 5/0 prefixes, 9/0 paths, scan interval 60 secs

    Neighbor        V           AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
    169.254.10.1    4        65000      40      43        6    0    0 00:06:03        4
    169.254.11.1    4        65000      40      44        6    0    0 00:06:04        4
    ip-10-4-0-17#
    ```

1.  We can also see what those routes are and how many paths we have with the **show ip routes** or **sh ip ro** command.

    ```
    ...<output omitted>
    Gateway of last resort is 10.4.0.1 to network 0.0.0.0

    S*    0.0.0.0/0 [1/0] via 10.4.0.1, GigabitEthernet1
          10.0.0.0/8 is variably subnetted, 7 subnets, 3 masks
    B        10.0.0.0/16 [20/100] via 169.254.11.1, 00:00:04
    S        10.4.0.0/16 is directly connected, GigabitEthernet1
    C        10.4.0.0/22 is directly connected, GigabitEthernet1
    L        10.4.0.17/32 is directly connected, GigabitEthernet1
    B        10.8.0.0/16 [20/100] via 169.254.11.1, 00:00:04
    B        10.16.0.0/16 [20/100] via 169.254.11.1, 00:00:04
    B        10.17.0.0/16 [20/100] via 169.254.11.1, 00:00:04
          169.254.0.0/16 is variably subnetted, 4 subnets, 2 masks
    C        169.254.10.0/30 is directly connected, Tunnel1
    L        169.254.10.2/32 is directly connected, Tunnel1
    C        169.254.11.0/30 is directly connected, Tunnel2
    L        169.254.11.2/32 is directly connected, Tunnel2
    ip-10-4-0-17#
    ```

1.  Notice that there is only one next-hop address fro each of the VPCs CIDRs. We can fix this by allow Equal Cost Multipathing (ECMP).
    Back in config mode we will add maximum-paths to 8:
    `ip-10-4-0-17# config t router bgp 65001 address-family-ipv4 maximum-paths 8 end`
    Now, run **sh ip ro** command again. See, both the tunnels are showing up!

          ```
          ...<output omitted>
          Gateway of last resort is 10.4.0.1 to network 0.0.0.0

          S*    0.0.0.0/0 [1/0] via 10.4.0.1, GigabitEthernet1
                10.0.0.0/8 is variably subnetted, 7 subnets, 3 masks
          B        10.0.0.0/16 [20/100] via 169.254.11.1, 00:00:13
                            [20/100] via 169.254.10.1, 00:00:13
          S        10.4.0.0/16 is directly connected, GigabitEthernet1
          C        10.4.0.0/22 is directly connected, GigabitEthernet1
          L        10.4.0.17/32 is directly connected, GigabitEthernet1
          B        10.8.0.0/16 [20/100] via 169.254.11.1, 00:00:13
                            [20/100] via 169.254.10.1, 00:00:13
          B        10.16.0.0/16 [20/100] via 169.254.11.1, 00:00:13
                            [20/100] via 169.254.10.1, 00:00:13
          B        10.17.0.0/16 [20/100] via 169.254.11.1, 00:00:13
                            [20/100] via 169.254.10.1, 00:00:13
                169.254.0.0/16 is variably subnetted, 4 subnets, 2 masks
          C        169.254.10.0/30 is directly connected, Tunnel1
          L        169.254.10.2/32 is directly connected, Tunnel1
          C        169.254.11.0/30 is directly connected, Tunnel2
          L        169.254.11.2/32 is directly connected, Tunnel2
          ip-10-4-0-17#
          ```

1.  Just to verify where those routes are coming from, we can take a look at the **Green Route Table**. _note: remember, it's under the **VPC** service and **Transit Gateway Route Tables** at the bottom of the left menu._ There should be **5** routes listed. Any ideas why only **4** show up on the CSR?

</p>
</details>

![Speficy Details Screenshot](./images/hybrid-routes-diagram.png)

   <details>
   <summary>Create Routes in the VPC to the Transit Gateway Attachments</summary><p>

While the CloudFormation Template created attachments to the VPCs and route tables for the transit gateway. We need to setup routing within the VPC. What traffic do we want going from each subnet to the Transit Gateway.

1. In the AWS Management Console change to the region you are working in. This is in the upper right hand drop down menu.

1. In the AWS Management Console choose **Services** then select **VPC**.

1. From the menu on the left, Scroll down and select **Route Tables**.

1. You will see the Route Tables listed in the main pane. Lets Start with NP1-_stack_name_-Private route table, Check the box next to it. Let take a look toward the the bottom of the paneland click the **Routes** tab. Currently, there is just one route, the local VPC route. Since the only way out is going to be the Transit Gateway, lets make our life simple and point a default route to the Transit Gateway Attachment. Click the **Edit Routes** in the **Routes** tab.

1. On the **Edit routes** page, Click the **Add route** button and enter a default route by setting the destination of **0.0.0.0/0**. In the Target drop-down, select **Transit Gateway** and pick your Transit Gateway create for this project. It should be the only one.
   ![Stack Complete](./images/vpc-defaultroute.png)

1. Repeat the above step for the following route tables:

- NP2-_stack_name_-Private
- P1-_stack_name_-Private

1. For the **DCS1-_stack_name_-Public** and **DCS1-_stack_name_-Private** where our NAT Gateway is, we need a special route. We already have a default route pointed at the Internet Gateway(IGW) for the public and to the Nat Gateway(NGW) for the private to get to the internet, so we need a more specific entry to route internally. Lets use the rfc 1918 10.0.0.0/8 CIDR as that can only be internal and allows for future exapansion without changes. Follow the steps above for both Route tables. Be sure not to alter the **0.0.0.0/0** route pointed to the IGW org NGW for these route tables.

1. Beacuse the Cloudformation template setup a Security Group to allow ICMP traffic from 10.0.0.0/8, we should now be able to test pings from lots of place.

1. In the AWS Management Console choose **Services** then select **EC2**.

1. From the menu on the left, Scroll down and select **Instances**.

1. In the main pane, select an EC2 instance from the list and copy it ip address down. Repeat for as many as you would like to test connectivity. In particular we want to test to the P1 server. Remember, we do not want our non prod instances to be able to reach our production servers or vice-versa.

- You can also get a list of IPs using the AWS CLI which you can run from the Cloud9 Instance. Heres one that extracts out all of them. The 10.16.x.x is the NP1, the 10.8.x.x is the P1 instance.

```
 aws ec2 describe-instances | grep "PrivateIpAddress" | cut -d '"' -f 4 | awk 'NR == 0 || NR % 4 == 0'
```

1. In the AWS Management Console choose **Services** then select **Systems Manager**. Systems Manager Gain Operational Insight and Take Action on AWS Resources. We are going to take a look a just one of seven capabilites of Systems Manager.

1. From the menu on the left, Scroll down and select **Session Manager**. Session Manager allows us to use IAM role and policies to determine who has console access without having to manage ssh keys for our instances.

1. In the main pane, click the **Start sesssion** button. Pick an Instance to shell into. You will now enter a bash shell prompt for that instance.

1. Let Ping a server. Every one second or so, you should see a new line showing the reply and roundtrip time.

```
ping 10.16.18.220
sh-4.2$ ping 10.16.18.220
PING 10.16.18.220 (10.16.18.220) 56(84) bytes of data.
64 bytes from 10.16.18.220: icmp_seq=1 ttl=254 time=1.09 ms
64 bytes from 10.16.18.220: icmp_seq=2 ttl=254 time=0.763 ms
64 bytes from 10.16.18.220: icmp_seq=3 ttl=254 time=0.807 ms
64 bytes from 10.16.18.220: icmp_seq=4 ttl=254 time=0.891 ms
64 bytes from 10.16.18.220: icmp_seq=5 ttl=254 time=0.736 ms
64 bytes from 10.16.18.220: icmp_seq=6 ttl=254 time=0.673 ms
64 bytes from 10.16.18.220: icmp_seq=7 ttl=254 time=0.806 ms
^C
--- 10.16.18.220 ping statistics ---
7 packets transmitted, 7 received, 0% packet loss, time 6042ms
rtt min/avg/max/mdev = 0.673/0.824/1.096/0.130 ms
```

      Troubleshooting: if you are unable to ping a server here are a few things to check:
      - Go to the EC2 service and reverify the private IP address of the device you want to ping from
      - Go to the       VPC service and verify that you have the 0.0.0.0/0 route point to the TGW for VPCs NP1,NP2, and P1. Verify that you have the 10.0.0.0/8 route in the DCS VPC for both public and private subnets while you are here.
      - Finally, Verify that you went through the check for the TGW route tables propagation and the CSR is receiving routes (see the **Setup VPN Between Datacenter and Transit Gateway** section above)

1. You can also verify Internet access by using the curl command on the NP1, NP2 or P1 (the Datacenter Server wont use the Transit Gateway to get to the internet, but should still work). If you curl https://cloudformation.us-east-1.amazonaws.com it should return healthy.

1. If you tested between the P1 server and a NP1 or NP2 server, you should have also seen a reply ping. But thats not what we wanted. Take a look at the VPC route table, the Associated Transit Gateway Route table (_for P1 this should be Blue, for NP1 or NP2 this should be Red_) Follow the logic to understand whats going on.

 <details>
   <summary>SPOLIER Fixing Mysterious Prod to Non-Prod routing</summary><p>

      While we do not have a direct route between the Production and Non-Production VPCs we do have a gateway through the NAT Gateway in the **Datacenter Services VPC**. Let's fix this through a routing mechinism called Blackhole routing (sometimes refered to as null routing).

1. In the AWS Management Console choose **Services** then select **VPC**.

1. From the menu on the left, Scroll down and select **Transit Gateway Routes Tables**.

1. From the table in the main panel select **Blue Route Table**. Lets take a look toward the bottom, and click the **Routes** tab.

1. Take a look at the existing routes and see the 0.0.0.0/0 route that is sending data destined for the Non-prod address to the **Datacenter Services VPC**. Let's prevent that. Click the **Add route** button.

1. At the Create route screen, for the **CIDR** enter **10.16.0.0/13** and check the box next to **Blackhole**. This will drop any traffic destined for the Non-Production VPCs. This is because TGW looks for the most specific route that matches and the /13 is more specific than the /0 route.

   ![Blackhole route](./images/tgw-blackholeroute.png)

1. Go back to Session Manager and connect to the P1 server and re-attempt to ping the NP1 or NP2 servers. Pings should fail now.

1. be sure to repeat the blackhole route in the **Red Route Table** by creating a blackhole route for 10.8.0.0/13.

   </p>
   </details>

</p>
</details>

### Build out DNS Infrastructure

Run CloudFormation template 3.tgw-dns.yaml to deploy the Bind server in the Datacenter as well as add AWS Route53 Resolver endpoints in the Datacenter Services VPC.

<details>
<summary>HOW TO Deploy the Bind Server</summary><p>

1. In the AWS Management Console change to the region you are working in. This is in the upper right hand drop down menu.

1. In the AWS Management Console choose **Services** then select **CloudFormation**.

1. In the main panel select **Create Stack** in the upper right hand corner.<p>
   ![Create Stack button](./images/createStack.png)

1. Make sure **Template is ready** is selected from Prepare teplate options.

1. At the **Prerequisite - Prepare template** screen, for **template source** select **Upload a template file** and click **Choose file** from **Upload a Template file**. from your local files select **3.tgw-dns.yaml** and click **Open**.

1. Back at the **Prerequisite - Prepare template** screen, clcik **Next** in the lower right.

1. For the **Specify stack details** give the stack a name, enter the name of your first stack (must be entered exactly to work), and select DNS compliant domain name, such as **kneetoe.com**. Click **Next**.
   ![Stack Parameters](./images/createStack-VPCparameters.png)

1. For **Configuration stack options** we dont need to change anything, so just click **Next** in the bottom right.

1. Scroll down to the bottom of the **Review name_of_youstack** and check the **I acknowledge that AWS CloudFormation might create IAM resources with custom names.** Click the **Create** button in the lower right.
   ![Create Stack](./images/createStack-VPCiam.png)

1. wait for the Stack to show **Create_Complete**.
   ![Stack Complete](./images/createStack-VPCComplete.png)

      </p>
      </details>

<details>
<summary>HOW TO Verify DNS communication</summary><p>
1. In the AWS Management Console choose **Services** then select **Systems Manager**.

1. From the menu on the left, Scroll down and select **Session Manager**. Session Manager allows us to use IAM role and policies to determine who has console access without having to manage ssh keys for our instances.

1. In the main pane, click the **Start sesssion** button. Pick The Datacenter Instance to shell into. You will now enter a bash shell prompt for that instance.

1. Let Ping np1.aws._your_domain_name_. Every one second or so, you should see a new line showing the reply and roundtrip time.

![DNS DC to DCS](./images/dns-dc1tonp1.png)

```

sh-4.2$ ping np1.aws.kneetoe.com
PING 10.16.18.220 (10.16.18.220) 56(84) bytes of data.
64 bytes from 10.16.18.220: icmp_seq=1 ttl=254 time=1.09 ms
64 bytes from 10.16.18.220: icmp_seq=2 ttl=254 time=0.763 ms
64 bytes from 10.16.18.220: icmp_seq=3 ttl=254 time=0.807 ms
64 bytes from 10.16.18.220: icmp_seq=4 ttl=254 time=0.891 ms
64 bytes from 10.16.18.220: icmp_seq=5 ttl=254 time=0.736 ms
64 bytes from 10.16.18.220: icmp_seq=6 ttl=254 time=0.673 ms
64 bytes from 10.16.18.220: icmp_seq=7 ttl=254 time=0.806 ms
^C
--- 10.16.18.220 ping statistics ---
7 packets transmitted, 7 received, 0% packet loss, time 6042ms
rtt min/avg/max/mdev = 0.673/0.824/1.096/0.130 ms
```

1. Since we dont allow pings the other way, lets test by using **Session Manager** to shell to NP1, and using dig to lookup a name provided by the Bind server in the Datacenter (test._your_domain_name_). It should return the private ip address of the Bind Server.

![DNS NP1 to DC](./images/dns-np1todc.png)

```
sh-4.2$ dig test.kneetoe.com

; <<>> DiG 9.9.4-RedHat-9.9.4-61.amzn2.0.1 <<>> test.kneetoe.com
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 59048
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;test.kneetoe.com.                  IN      A

;; ANSWER SECTION:
test.kneetow.com.           60      IN      A       10.4.12.187

;; Query time: 5 msec
;; SERVER: 10.16.0.2#53(10.16.0.2)
;; WHEN: Fri Feb 01 16:33:27 UTC 2019
;; MSG SIZE  rcvd: 57

</p>
</details>


### Removal

1. Before deleting the Cloudformation templates, Delete the Site-to-Site VPN from the VPC services console.

1. Delete the Cloudformation templates in reverse order:
   - 3.tgw-.yaml
   - 2.tgw-csr.yaml (be sure you removed the Site-to-Site VPN form the VPC services first or it will fail to remove and you will have to do it again!)
   - 1.tgw-vpcs.yaml (this will also removed the cloud9 stack, no need to manual delete that stack)

# To Do:

1. add AWS Resolver from geseib/awsresolver to this environment with Bind server in Datacenter Services VPC which connects to on Prem Bind Server.
1. add Second prod VPC from another account instructions
1. add Shared VPC subnets in the non-prod VPC and give access from the account used in step 3.
1. add a AD in on prem DC connected to AD in Datacenter Services and SSO
```
