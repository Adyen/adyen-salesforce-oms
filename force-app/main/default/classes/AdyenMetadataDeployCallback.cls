public class AdyenMetadataDeployCallback implements Metadata.DeployCallback {

    public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {

        if (result.status == Metadata.DeployStatus.Succeeded) {
            System.debug('Custom Metadata update succeeded: ' + result.id);
            // Todo: handle success scenario
        } else {
            System.debug('Custom Metadata update failed: ' + result.errorMessage);
            // Todo: handle failure scenario
        }
    }
}