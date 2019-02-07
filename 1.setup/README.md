# 1. Transit Gateway Lab setup

Using a predefined CloudFormation template, we will deploy a Simulated Datacenter in a VPC, as well as several VPC for our Non-production, Production, and Shared Services environments.

![Specify Details Screenshot](../images/hybrid-tgw-diagram.png)

## Getting Started

First, we need to get our infrastructure in place. The following CloudFormation template will build out _five_ VPCs. In order to do that we will first remove the default VPC. \*note: if you ever remove you default VPC in your own account, you can recreate it via the console or the CLI see the [documentation](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html#create-default-vpc "AWS Default VPC Documentation").

### Pick Region

Since we will be deploying Cloud9 into our Datacenter VPC, we need to pick one of the following Regions:

- N. Virginia (us-east-1)
- Ohio (us-east-2)
- Oregon (us-west-2)
- Ireland (eu-west-1)
- Singapore (ap-southeast-1)

### 1. Delete Default VPC

A default VPC is automatically created for each region in your account. Some customers choose to remove the Default VPC and replace with ones they have planned out to keep things simple and secure. We are going to remove the default VPC for another reason: the number of VPCs per region in an account is soft limited to 5 and our Lab uses five VPCs. If you require more than five in your own accounts, its easy to increase them by making a limit request through the support console, while logged into your account: https://console.aws.amazon.com/support/cases#/create.

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
   ![Create Stack button](../images/createStack.png)

1. Make sure **Template is ready** is selected from Prepare template options.

1. At the **Create stack** screen, for **Template source** select **Upload a template file** and click **Choose file** from **Upload a Template file**. from your local files select **1.tgw-vpcs.yaml** and click **Open**.

1. Back at the **Create stack** screen, click **Next** in the lower right.

1. For the **Specify stack details** give the stack a name (be sure to record this, as you will need it later) and Select two Availability Zones (AZs) to deploy to. \*We will be deploying all of the VPCs in the same AZs, but that is not required. Click **Next**.
   ![Stack Parameters](../images/createStack-VPCparameters.png)

1. For **Configuration stack options** we dont need to change anything, so just click **Next** in the bottom right.

1. Scroll down to the bottom of the **Review name_of_your_stack** and check the **I acknowledge that AWS CloudFormation might create IAM resources with custom names.** Click the **Create** button in the lower right.
   ![Create Stack](../images/createStack-VPCiam.png)

1. wait for the Stack to show **Create_Complete**.
   ![Stack Complete](../images/createStack-VPCComplete.png)

      </p>
      </details>

<details>
<summary>Investigate the VPCs</summary><p>

## Look at the Subnets, route tables, etc.

1. In the AWS Management Console change to the region you plan to work in and change. This is in the upper right hand drop down menu.

1. In the AWS Management Console choose **Services** then select **VPC**.

1. From the left-hand menu select **Your VPCs**.

1. Notice we have Created the following VPCs

   - P1-_your_stack_name_
   - NP1-_your_stack_name_
   - NP2-_your_stack_name_
   - DCS1-_your_stack_name_
   - DS1-_your_stack_name_

   ![VPCs](../images/vpc-yourvpcs.png)

1. Feel free to look around other aspects of the VPC, such as the **subnets** and the **route tables**. You will notice for example both NP1-_your_stack_name_-Priv-A Subnet and NP1-_your_stack_name_-Priv-B Subnet share a same **Route table**, NP1-_your_stack_name_-Private Route Table. And that Route table only has a route for the local VPC CIDR block. We will be changing that in the next lab, so that you can route outside of the NP1 VPC.

   ![VPC Route Table](../images/vpc-routetable.png)

## Connect to the shell of a Linux EC2 instance

1. In the AWS Management Console choose **Services** then select **Systems Manager**. Systems Manager Gain Operational Insight and Take Action on AWS Resources. We are going to take a look a just one of seven capabilities of Systems Manager.

1. From the menu on the left, Scroll down and select **Session Manager**. Session Manager allows us to use IAM role and policies to determine who has console access without having to manage ssh keys for our instances.

1. In the main pane, click the **Start session** button. Pick an Instance to shell into. You will now enter a bash shell prompt for that instance.

1. Run a few commands like **ifconfig** or **cat /etc/resolv.conf**

   ```
   sh-4.2$ ifconfig
   eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 9001
           inet 10.16.21.58  netmask 255.255.248.0  broadcast 10.16.23.255
           inet6 fe80::13:45ff:fe79:926c  prefixlen 64  scopeid 0x20<link>
           ether 02:13:45:79:92:6c  txqueuelen 1000  (Ethernet)
           RX packets 963  bytes 177300 (173.1 KiB)
           RX errors 0  dropped 0  overruns 0  frame 0
           TX packets 1474  bytes 317453 (310.0 KiB)
           TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

   lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
           inet 127.0.0.1  netmask 255.0.0.0
           inet6 ::1  prefixlen 128  scopeid 0x10<host>
           loop  txqueuelen 1000  (Local Loopback)
           RX packets 8  bytes 648 (648.0 B)
           RX errors 0  dropped 0  overruns 0  frame 0
           TX packets 8  bytes 648 (648.0 B)
           TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

   sh-4.2$ cat /etc/resolv.conf
   ; generated by /usr/sbin/dhclient-script
   search us-west-2.compute.internal
   options timeout:2 attempts:5
   nameserver 10.16.0.2
   ```

</p>
</details>

# Congratulations

You now have **completed** this section. Continue to the [Setup Transit Gateway and VPN module](../2.singleaccount) , to setup communication between VPCs and the Datacenter.
