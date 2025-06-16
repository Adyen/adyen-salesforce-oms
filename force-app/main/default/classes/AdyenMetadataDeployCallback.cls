public class AdyenMetadataDeployCallback implements Metadata.DeployCallback {

    public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
        Adyen_Metadata_Deployment_Result__e deploymentEvent = new Adyen_Metadata_Deployment_Result__e(
            Deployment_Id__c = result.id,
            Is_Success__c = (result.status == Metadata.DeployStatus.Succeeded),
            Error_Message__c = result.status == Metadata.DeployStatus.Succeeded ? null : result.errorMessage
        );

        EventBus.publish(deploymentEvent);
    }
}