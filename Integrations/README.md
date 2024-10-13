# Overview

**URL For Git Repo Import into Azure Devops:**  
https://github.com/LeeKnight344/D365-FinOps-StarterKit.git

This guide walks users through creating the Azure resources required for setting up recuring integrations between thrid party systems with Odata requests used to get information into F&O and Data Events used as the primary way to get data out of F&O based on CRUD actions.

### The resources included in the Bicep Files are as follows:

#### Synapse Link with Azure Hosted/On-Prem Hosted SQL Database:
- Storage Account linked to App Service
- App Service Plan
- Logic App Standard (App Service Plan Hosted)
- Application Insights and Log Analytics Workspace per environment
- Standard Sku Azure Service Bus Namespace, with pre-built topics & Subscriptions
- Key Vault


## Branch Triggers

This repository by default operates off of a fairly standard branching methodoogy that can be improved upon depending on your or your clients specific needs. Releases to certain envrionemnts are mainly controlled through the Azure Devops Environments blade which can be found by navigating to `Pipelines > Environments > {Environment Name}`:
![alt text](Integrations.Screenshots\DevopsEnvironments.png)


From here you can set approvals and checks against the environments, in my setup I have any commits going into the Development branch trigggering deployments into Development. Any PRs going into main trigger deployments into UAT which have approvals setup against it, deployments inyo Production require the UAT deployment stage to have succeeded and also requires an approval. 

Approvals can be configured by selecting one of the environments,  selecting 'Approvals and Checks' and then selecting the '+' button:

![alt text](Integrations.Screenshots\DevopsEnvironments-ApprovalsandChecks.png)

Configuring approvals against environments is a good way to control releases into environments while still allowing releases to be automatically triggered by completed Pull Requests. If you want to stop these requests you need to navigate to the YLM files and comment out the environments element:

![alt text](Integrations.Screenshots\RemoveEnvironmentYMLConfig.png)


## Prerequisites
1. Create and configure an Azure DevOps organization and project.
2. Create a service connection to your Azure subscription that you'll be deploying resources to. Refer to the [Service Connection Documentation](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops).
3. Import this repository into your DevOps Project:

    - Navigate to `Repos > Select the Dropdown > Select Import Repository`

    ![RetrieveConnectionString](Integrations.Screenshots\ImportRepository.png)

    - Input the provided Git URL and give the repository a new name:

    ![RetrieveConnectionString](Integrations.Screenshots\ImportRepository2.png)

4. Next you'll need to create an App Registration. This'll be used to communicate with the Dataverse entities that F&O Data Events have been activated for
 

  - Navigate to entra.microsoft.com
  - Select Applications > App Registrations > New Registration:

    ![alt text](Integrations.Screenshots\entraid.png)

  - Name the new app registration accordingly, we need to repeat this for however many environments you have so that we have 1 app registration per environment. in my case I have three environments, dev, UAT and Production so I'll create three app registrations.

    ![alt text](Integrations.Screenshots\appregistrationcreation.png)

  - Ensure to note down the display name, the Application ID and the Object ID for each application you create, we'll need these later when defining the parameters on the YML deployment templates:

    ![alt text](Integrations.Screenshots\appid&objid.png)

 - For Each application create a new secret key by going to secrets > new secret, ensure to note down the secret key after this as you will not be able to retrieve it after refreshing the page. Also make sure to note down the expirey date of the secret key as when this expires you'll need to create a new one and update your configuration accordingly:

    ![alt text](Integrations.Screenshots\clientsecret.png)

 - Now navigate to admin.powerplatform.microsoft.com and select each environment you created an app registration for, go to settings:

    ![alt text](Integrations.Screenshots\settings.png)

- Select Application Users under Users + Permissions:

    ![alt text](Integrations.Screenshots\userpermissions.png)

- Add each application user for each environment as a System Administrator:

   ![alt text](Integrations.Screenshots\addtoenvs.png)
   ![alt text](Integrations.Screenshots\sysadmin.png)

- After you have performed the above for all of your environments we'll also need to do the same for the integrated Finance & Operations Environment. To do this copy the application ID for each app and navigate to each F&O environment, go to System Administration > Setup > Microsoft Entra ID Applications and add your app registration as a System Administrator. *While for Dev/Testing the System Administrator role is good to use it's highly reccomended to create custom secutiry roles for these integration scenarios*
: 

    ![alt text](Integrations.Screenshots\fosysadmin.png)


## Resource and Code Deployments

1. Set up the deployment pipelines with the provided `.yml` files. There is a deployment pipeline for the Azure Resources and one for the Logic App codebase, the paths to which are as follows:

    - **Azure Resources Deployment**: `Integrations\Azure.Resources\AZ.Integrations.bicep`
    - **Logic App Codebase Deployment**: `Integrations\LogicApp.Projects\LogicApp.Project.build.yml`

    - Select `New Pipeline`, then choose `Azure Repos Git`:

        ![AzureReposGit](Integrations.Screenshots\AzureReposGit.png)

    - Choose the option to use an existing `.yml` file:

        ![ExistingYML](Integrations.Screenshots\ExistingYML.png)

    - Use the newly created repository:

        ![RepoName](Integrations.Screenshots\RepoName.png)

    - Select the path of the `.yml` file:

        ![alt text](Integrations.Screenshots\ymlforintresources.png)

    - Ensure to save and not run:

        ![Save](Integrations.Screenshots\save.png)

    - Rename the pipeline to make it easier to view from the Pipelines overview board:

        ![RenamePipeline](Integrations.Screenshots\RenameAndMove.png)


2. Change the Parameter values for your YML stages by editing the YML files, these will dictate the names for the related resources/login information:

![alt text](Integrations.Screenshots\toplevelparams.png)


 - An Important set of parameters to note are *AZ_APIS_Dataverse_Client_ID, AZ_APIS_Dataverse_Client_Secret, AZ_APIS_Dataverse_Object_ID* these are referencing the app registrations we generated earlier and their values need to be filled in for each environment accordingly. The Client Secret needs to be populated from the Variable groups which I talk through below, the rest can be set for each stage directly in the YML template. As well as this ensure to fill out AZ_APIS_Dataverse_URL as this is used when sending Odata requests into Dataverse:

 ![alt text](Integrations.Screenshots\PARAMS.png)

3. Create variable groups for your Development, UAT, and Production environments:
   - **Integrations - Secure Development Variables**
   - **Integrations - Secure UAT Variables**
   - **Integrations - Secure Production Variables**

    Add required values to these groups, this is the service principal secret that you'll use to get bearer tokens for Dataverse:

    ![alt text](Integrations.Screenshots\variablelibaryintegrations.png) -->


4. Run the Azure Resource deployment pipeline, the path for this one should be `Integrations\Azure.Resources\AZ.Integrations.bicep` as previously mentioned on step 1 of this guide

    ![alt text](Integrations.Screenshots\integrationsresourcepipelinerun.png)

5. Run the logic app codebase deployment pipeline.

    ![alt text](Integrations.Screenshots\logicworkflowdeploymentpipeline.png)


6. By this point you have deployed all of your Required Azure resources as well as the code for the logic app to run a small set of different integrations for Customers, System Users and Annata A365 Devices. To confirm this navigate to the Azure Portal and find the resource group you setup in the YML files. If you have followed the structure of the YML files the resource group should be named something along the lines of 'CustomerPrefix'-integrations-'EnvironmentPrefix'-rg. Once found confirm that all of your resources have succesfully deployed:

![alt text](Integrations.Screenshots\resourcesinportal.png)




## Logic Workflow CI/CD


**To setup and configure your development environment with VS Code please follow the guidelines listed on Microsoft Learn Here - https://learn.microsoft.com/en-us/azure/logic-apps/create-single-tenant-workflows-visual-studio-code**

The Logic app build and deploy pipeline will trigger when the workflow.json files are edited, aka when the logic workflows are edited. 


Logic Apps (Standard) support full development processes, much akin to that of Function Apps. With this solution all logic app workflows run on a single standard logic app hosted by an app service plan, all of which can be developed on through VS Code using the Logic App Standard Extension. 

In this Repository all of the custom logic app code is stored under the LogicApp.Projects folder, within here are all of the workfows (folders appended with logic-, under each of these folders are workflow.json files which contain the workflow definitions). Also within this project are the asociated artifacts like XML Schemas, XSLT Maps ect..these are used in order to transform output Data Events into canonical message formats ready for other systems to consume. 

There are also some primary files to note:

 - Connections.json - Within here you'll find the connection definitions for the service bus namespace, Dataverse and the logi analytics workspace. Only the service bus namespace connection reference is used in this repos solution however the others can easilty be used if needed, these values are pulled directly from the app settings from each logic app service environment which are set during the bicep deployments for each environment 

      ![alt text](Integrations.Screenshots\parametersjson.png)

 - parameters.json - This file contains the paramete defintions for environment specific values such as the dataverse environment URL, they pull their values from the environment logic apps app settings which, again, are set during each BICEP deployment stage per environment: 

      ![alt text](Integrations.Screenshots\connectionsjson.png)




## Service Bus Architecture

In order to route messages to or from F&O we use a service bus namespace, this Azure resource acts as a message broker between F&O, the Logic Workflows and Third Party/External Systems. There are three entity types when it comes to service bus namespaces, these are:

 - Queues: A queue is a messaging entity inside the namespace that enables one-way communication where a message is sent and stored until it is received and processed by a receiver. It follows a first-in, first-out (FIFO) model, meaning that messages are processed in the order they arrive, the systems sending and recieving the messages never communicate directly. 
  

 - Topics & Subscriptions: A topic is similar to a queue in that it stores messages, but instead of one receiver, it allows multiple subscribers to receive messages. It enables one-to-many communication where a single message sent to a topic can be delivered to multiple subscriptions.The subscriptions that the message gets routed to depends on the message contents/properties. For example, if the message is of the type 'customer broadcast' then the message gets directed to the customers subscription.

 Using this Framework we can enable F&O to send messages out to a topic and direct them to be processed by different logic workflows based on their message types, again as an example if a customer create data event is sent out then the logic workflow 'logic-customer-outbound-d365' triggers and processes the message as it is looking at the subscription that the message got routed to. In this repostiroy we have musltiple topics/subscriptions that have been pre-configured to work with F&O Data Events, an easy one to use is a Customer getting created. Firstly we need to activate the Data Event from F&O following the below steps:

 **Outbound Customer**

  1. Navigate to the Finance & Opeations Environment > System Administration > Business Events Catalog. 

  2. Select the Endpoints tab and select '+ New Endpont':

![alt text](Integrations.Screenshots\newendpoint.png)

  3. From the Dropdown select Azure Service Bus Topic and press next:

  ![alt text](Integrations.Screenshots\topic.png)

  4. For the parameters copy exactly what I have put for the first three text boxes, for the the next three you'll need to grab your Key Vault DNS name and your Client ID/Secret. For the Key Vault secret name you can use AzureServiceBusSASKey as this is what has been defined for the secret name in the Bicep template:

![alt text](Integrations.Screenshots\endpointparameters.png)


  5. Now that the endpoint has been created we can activate our customer data event, to do this go to the Data Event Catlog and filter for the names that contain 'DataEvent_CustCustomerV3Entity': 

  ![alt text](Integrations.Screenshots\custde.png)

  6. Select all three and click activate (you can also select only the actions you want as well, not all of them need to be on for this to work). You'll be greeted with a processing screen, this'll take about a minute if the virtual entity hasn't already been activated in Dataverse:

  ![alt text](Integrations.Screenshots\processing.png)

  7. Select the Endpoint we created earlier, leave the legal entity dropdown blank unless you want to activate this integration only for specific LEs:

  ![alt text](Integrations.Screenshots\endpoint.png)

  8. Now that the data event is active we can test it out, go to the All Customers Tab and edit/create a customer, once this has been done you will trigger the logic-customer-outbound-d365 workflow which will place a customer broadcast message into the sbt-integration-d365-outbound-completed sbs-customers subscription. 

**Inbound Customer**

  1. Inbound messages work in pretty much the same fashion as the above, while utilising different topics/subscriptions for message filtering. In a real world scenario we would be using a third party system to send this message out to our target API which may be an externally facing Logic App or Function app used to route messages into our internal service bus. However because this is a demo setup we will need to manually send the message through to the service bus with the correct parameters. 

  2. I have got some sample messages ready for this test within the repo under `Integrations\Sample Files`, select the CustomerBroadcast.xml and copy its contents. 

  3. Now navigate to your Azure service bus > Entities > Topics > sbt-integration-d365-inbound:

  ![alt text](Integrations.Screenshots\inboundtopic.png)

  4. Select Service Bus Explorer > Send Messages:

  ![alt text](Integrations.Screenshots\sendmessage.png)

  5. Paste the customer broadcast message into the text box and set the content type to application/xml, fill in the parameters as I have done below and then press send:

  ![alt text](Integrations.Screenshots\sendparams.png)

  6. This routes the message through the logic-customer-d365-inbound workflow and creates/updates/deletes the record based on the contents and properties of the message

  7. To view the workflow run histories go to the logic app resource > Workflows:

  ![alt text](Integrations.Screenshots\workflows.png)



<!--TO DO Create Guide on Logic App Development -->