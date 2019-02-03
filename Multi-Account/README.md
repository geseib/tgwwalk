# Multi-Account Sharing

Let's Extend this out a bit. Many organziations want to segment out their deployment at an account level. This works great for creating easy boundries for permissions, account limits, and general organziation.

AWS Resource Access Manager (RAM) is a service that enables you to easily and securely share AWS resources with any AWS account or within your AWS Organization. You can share AWS Transit Gateways, Subnets, AWS License Manager configurations, and Amazon Route 53 Resolver rules resources with RAM.
We are going to use three of those: our Transit Gateway, the two private subnets in Non-Prod VPC, and the Route53 Rule for looking up on-prem DNS names.

\*Note: in order to complete this section we need another AWS account. and we need to perform these steps in the same Region as the Transit Gateway was built in using the previous section. This works well, pairing up with someone else also doing the labs, and connecting this new VPC to their Transit Gateway.

![Speficy Details Screenshot](../images/Multiaccount-diagram.png)

## Share the Transit Gateway for Cross-Account Access

The first scenario we want to walk through is sharing the Transit Gateway so that we can easily route between VPCs that are in other accounts but still in our organization. We can share outside of our organziation too through invitations. In this case we are going to share with the organziation.

1. In the AWS Management Console change to the region you plan to work in and change. This is in the upper right hand drop down menu.

1. Lets determine the scope of the share. If you are pairing up with someone, choose **Option 1** below, we will use their Account number. If you are working in your Organziation, you can also use **Option 2** and share with all of the account in your AWS organization.
   **OPTION 1**

   - Pair up with someone else completing this walkthrough and share your account number with them, and jot their account nuymber down as well. You will use this when identifying **Principals** later.
     You will connect a new VPC to their Transit Gateway and they will connect a new VPC to your Accounts Transit Gateway

   **OPTION 2**

   - Just to the left of the Region Drop down, click on your login drop-down menu and select **My Organziation**. On **Your account belongs to the following organization:** screen, make a note of the **Organization ID** (it will start with an **o-**)

1. In the AWS Management Console choose **Services** then select **Resource Access Manager**.

1. From the left-hand menu select **Resource Shares** (you may have to open the Burger menu). Click the **Create a resource share** button in the upper right of the main panel.

1. Fill out the **Create Resource Share** details:

- **Name** - give it a Descriptive name for the Share
- **Seclect Resource type** - from the drop down select **Transit Gateways**.
- **ID** - from the list, select the Transit Gateway you created for the Lab
- **Principals - optional** - in the seach box, paste the account number or organization ID you recorded a few steps up (depending on which option you picked above). Click the **add** button to the right.
  Verify you have everything entered correctly and click the **Create resource share** in the bottom right of the main panel.

## Create A new VPC for Non-Production

Run CloudFormation template 4.tgw-vpcs.yaml to deploy the VPC in the Same Region as the other accounts Transit Gateway was built in.

<details>
<summary>HOW TO Deploy the VPC</summary><p>

1. In the AWS Management Console change to the region the VPCs and Transit Gateway were created **IN THE OTHER ACCOUNT**. This is in the upper right hand drop down menu. _note: Today, AWS Transit Gateway can only attach to VPCs in the same region as the Transit Gateway. There are archtiectures that allow for a multi-region design, for example using VPN and a Transit VPC. This is out of scope for this lab._

1. In the AWS Management Console choose **Services** then select **CloudFormation**.

1. In the main panel select **Create Stack** in the upper right hand corner.<p>

   ![Create Stack button](../images/createStack.png)

1. Make sure **Template is ready** is selected from Prepare template options.

1. At the **Prerequisite - Prepare template** screen, for **template source** select **Upload a template file** and click **Choose file** from **Upload a Template file**. from your local files select **1.tgw-vpcs.yaml** and click **Open**.

1. Back at the **Prerequisite - Prepare template** screen, clcik **Next** in the lower right.

1. For the **Specify stack details** give the stack a name and Select two Availability Zones (AZs) to deploy to. _We will be deploying all of the VPCs in the same AZs, but that is not required by AWS Trasnit Gateway_. Click **Next**.
   ![Stack Parameters](../images/createStack-CROSSparameters.png)

1. For **Configuration stack options** we dont need to change anything, so just click **Next** in the bottom right.

1. Scroll down to the bottom of the **Review name_of_youstack** and check the **I acknowledge that AWS CloudFormation might create IAM resources with custom names.** Click the **Create** button in the lower right.
   ![Create Stack](../images/createStack-VPCiam.png)

1. Wait for the Stack to show **Create_Complete**.
   ![Stack Complete](../images/createStack-CROSScomplete.png)

      </p>
      </details>

## Create a Transit Gateway Attachment to the Shared Transit Gateway

In the earlier deployment of our Trasnit Gateway, we allowed CloudFormation to deploy our Attachments to the VPCs. This time we will walk through the install manually.

1. In the AWS Management Console change to the region you are working in. This is in the upper right hand drop down menu.

1. In the AWS Management Console choose **Services** then select **VPC**.

1. From the menu on the left, Scroll down and select **Transit Gateway Attachments**.

1. You will see the VPC Attachments listed, but we want to add one to connect our Datacenter. Click the **Create Transit Gateway Attachment** button above the list.

1. Fill out the **Create Transit Gateway Attachment** form.

- **Transit Gateway ID** select the TGW from the list that is from the other account.
- **Attachment Type** is **VPC**
- **Attachment name tag** give it a descriptive name.
- **DNS supprt** leave enabled.
- **IPv6 supprt** leave unchecked
- **VPC ID** select the ID that has the name: NP3-_stack_name_ from the list
- **Subnet IDs** check the two subnets that end in **Attach-A Subnet** and **Attach-B Subnet**.
  Verify you have everything entered correctly and click the **Create attachment** in the bottom right of the main panel.

1. Click **close**

1. Still on the **VPC** Service console, from the menu on the left Scroll up and select **Route Tables**

1. You will see the Route Tables listed in the main pane. Select NP3-_stack_name_-Private route table, Check the box next to it. Let take a look toward the the bottom of the paneland click the **Routes** tab. Currently, there is just one route, the local VPC route. Since the only way out is going to be the Transit Gateway, lets make our life simple and point a default route to the Transit Gateway Attachment. Click the **Edit Routes** in the **Routes** tab.

1. On the **Edit routes** page, Click the **Add route** button and enter a default route by setting the destination of **0.0.0.0/0**. In the Target drop-down, select **Transit Gateway** and pick your Transit Gateway create for this project. Make sure its the one in the other account, not the account you are currently logged into.
   ![Stack Complete](../images/vpc-defaultroute.png)

   ### Now we need to manage the routing in Transit Gateway account.

1. From the Menu on the Left Select **Transit Gateway Attachments** to give the VCP attachment a name. Scan down the **Resource type** column for the Attachment with the **Name** blank. You can verify this Attachment is from the other Account by looking at the **Details** tab at the bottom of the main panel. The **Resource owner account ID** will be the other AWS account ID. \*note: Back at the top, if you click the pencil that appears when you mouse over the **Name** column, you can enter a name thats differnt than the first VPN. Be sure to click the _check_ mark to save the name.

1. From the Menu on the Left Select **Transit Gateway Route Tables**. From the table in the main panel select **Red Route Table**. Lets take a look toward the bottom, and click the **Associations** tab. Associations mean that traffic coming from the outside toward the Transit gateway will use this route table to know where the packet will go after routing through the TGW. _note: An attachment can only be Associated with one route table. But a route table can have multiple associations_. Here in the **Red Route Table**, click **Create associations** in the **Associations** tab. From the drop-down list, select the NP3 vpc . _note:it should be the only one in the list without a **Association route table** ._ Click **Create assocation**.
   ![Associate VPN](../images/tgw-vpnassocationspending.png)

1. While at the **Transit Gateway Route Tables**, take a look at the **Propagations** tab. These are the Resources that dynamically inform the route table. An attachment can propigate to multiple route tables. For the New Non-Production (NP3) VPC, we want to propagate to the Non-Prod(Red) route table and the Datacenter/Datacenter Services ROute table (Green) route table. Lets start with the **Red Route Table**. We can see all of the VPCs are propagating their CIDR to the route table.

1. Repeat the above step on the propagations tab for the **Green Route Table**.
