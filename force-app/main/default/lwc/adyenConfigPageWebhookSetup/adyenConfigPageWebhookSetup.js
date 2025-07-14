import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe } from 'lightning/empApi';
import getWebhookUrl from '@salesforce/apex/AdyenWebhookSetupController.getWebhookUrl';
import setupWebhook from '@salesforce/apex/AdyenWebhookSetupController.setupWebhook';
import saveHmacToMetadata from '@salesforce/apex/AdyenWebhookSetupController.saveHmacToMetadata';
import testWebhook from '@salesforce/apex/AdyenWebhookSetupController.testWebhook';

const METADATA_UPDATE_TIMEOUT = 10000;

export default class AdyenConfigPageWebhookSetup extends LightningElement {
    description = 'Adyen Webhook for Salesforce OMS';
    selectedEventCodes = ['CAPTURE', 'CAPTURE_FAILED', 'REFUND', 'REFUND_FAILED'];
    webhookUrl = '';
    isLoading = false;
    webhookSetupResult = null;
    setupError = '';
    isDropdownOpen = false;
    
    hmacKey = '';
    hmacGenerationFailed = false;
    hmacErrorMessage = '';
    hmacSavedToMetadata = false;
    isHmacVisible = false;
    
    channelName = '/event/Adyen_Metadata_Deployment_Result__e';
    subscription = null;
    timeoutId = null;
    pendingDeploymentId = '';
    deploymentTimedOut = false;
    isMetadataSaveLoading = false;

    eventCodeOptions = [
        { label: 'CAPTURE', value: 'CAPTURE' },
        { label: 'CAPTURE_FAILED', value: 'CAPTURE_FAILED' },
        { label: 'REFUND', value: 'REFUND' },
        { label: 'REFUND_FAILED', value: 'REFUND_FAILED' },
        { label: 'CANCELLATION', value: 'CANCELLATION' },
        { label: 'AUTHORISATION', value: 'AUTHORISATION' }
    ];
    
    connectedCallback() {
        this.loadWebhookUrl();
        this.subscribeToHmacDeploymentEvents();
    }
    
    disconnectedCallback() {
        this.unsubscribeFromHmacDeploymentEvents();
        this.clearTimeout();
    }
    
    subscribeToHmacDeploymentEvents() {
        subscribe(this.channelName, -1, (event) => this.handleHmacDeploymentEvent(event))
            .then(response => {
                this.subscription = response;
            })
            .catch(error => {
                this.handleError(error);
            });
    }
    
    unsubscribeFromHmacDeploymentEvents() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }
    
    handleHmacDeploymentEvent(event) {
        const eventData = event.data.payload;
        if (eventData.Deployment_Id__c === this.pendingDeploymentId) {
            this.clearTimeout();
            this.isMetadataSaveLoading = false;
            this.pendingDeploymentId = '';
            
            if (eventData.Is_Success__c) {
                this.handleMetadataSaveSuccess();
            } else {
                this.handleMetadataSaveError(eventData.Error_Message__c);
            }
        }
    }
    
    startTimeout() {
        this.clearTimeout();
        this.deploymentTimedOut = false;
        this.timeoutId = setTimeout(() => {
            if (this.pendingDeploymentId) {
                this.isMetadataSaveLoading = false;
                this.deploymentTimedOut = true;
                
                this.showToast(
                    'Save Taking Longer Than Expected',
                    'The HMAC key save is still processing. You can continue with other setup steps.',
                    'warning'
                );
            }
        }, METADATA_UPDATE_TIMEOUT);
    }
    
    clearTimeout() {
        if (this.timeoutId) {
            clearTimeout(this.timeoutId);
            this.timeoutId = null;
        }
    }
    
    handleDropdownFocusOut(event) {
        const dropdown = this.template.querySelector('[data-id="event-dropdown"]');
        if (!event.relatedTarget || !dropdown.contains(event.relatedTarget)) {
            this.isDropdownOpen = false;
        }
    }
    
    async loadWebhookUrl() {
        this.isLoading = true;
        try {
            this.webhookUrl = await getWebhookUrl();
        } catch (error) {
            this.handleError(error);
        } finally {
            this.isLoading = false;
        }
    }
    
    handleDescriptionChange(event) {
        this.description = event.target.value;
    }
    
    handleDropdownToggle(event) {
        event.stopPropagation();
        this.isDropdownOpen = !this.isDropdownOpen;
    }
    
    handleEventSelectionChange(event) {
        event.stopPropagation();
        
        const eventCode = event.target.dataset.event || event.currentTarget.dataset.event;
        const isCheckbox = event.target.type === 'checkbox';
        const isCurrentlySelected = this.selectedEventCodes.includes(eventCode);
        
        const shouldSelect = isCheckbox ? event.target.checked : !isCurrentlySelected;
        
        this.updateEventSelection(eventCode, shouldSelect);
        
        if (!isCheckbox) {
            const checkbox = this.template.querySelector(`lightning-input[data-event="${eventCode}"]`);
            if (checkbox) {
                checkbox.checked = shouldSelect;
            }
        }
        
        this.isDropdownOpen = true;
    }
    
    updateEventSelection(eventCode, isSelected) {
        if (isSelected && !this.selectedEventCodes.includes(eventCode)) {
            this.selectedEventCodes = [...this.selectedEventCodes, eventCode];
        } else if (!isSelected) {
            this.selectedEventCodes = this.selectedEventCodes.filter(code => code !== eventCode);
        }
    }
    
    async handleSetupWebhook() {
        if (!this.isValidInput()) {
            return;
        }
        
        this.isLoading = true;
        this.setupError = '';
        this.webhookSetupResult = null;
        this.hmacKey = '';
        this.hmacGenerationFailed = false;
        this.hmacErrorMessage = '';
        this.hmacSavedToMetadata = false;
        
        try {
            const result = await setupWebhook({
                description: this.description,
                eventCodes: this.selectedEventCodes
            });
            
            if (result.isSuccess) {
                this.webhookSetupResult = result;
                this.hmacKey = result.hmacKey || '';
                this.hmacGenerationFailed = result.hmacGenerationFailed || false;
                this.hmacErrorMessage = result.hmacErrorMessage || '';
                
                let toastMessage = 'Webhook has been successfully configured';
                if (this.hmacGenerationFailed) {
                    toastMessage += ', but HMAC generation failed';
                } else if (this.hmacKey) {
                    toastMessage += ' with HMAC key generated';
                }
                
                this.showToast(
                    'Webhook Setup Successful',
                    toastMessage,
                    this.hmacGenerationFailed ? 'warning' : 'success'
                );
            } else {
                this.setupError = result.errorMessage;
                this.handleError(result.errorMessage, 'Setup Failed');
            }
        } catch (error) {
            this.setupError = error.message;
            this.handleError(error, 'Setup Failed');
        } finally {
            this.isLoading = false;
        }
    }
    
    async handleSaveHmacToMetadata() {
        if (!this.hmacKey) {
            this.showToast('Error', 'No HMAC key available to save.', 'error');
            return;
        }
        
        this.isMetadataSaveLoading = true;
        this.deploymentTimedOut = false;
        
        try {
            const deploymentId = await saveHmacToMetadata({ hmacKey: this.hmacKey });
            
            this.pendingDeploymentId = deploymentId;
            this.startTimeout();
            
            this.showToast(
                'HMAC Key Save In Progress',
                'Saving HMAC key to metadata. This may take a moment.',
                'info'
            );
            
        } catch (error) {
            this.isMetadataSaveLoading = false;
            this.handleError(error, 'Save Failed');
        }
    }
    
    handleMetadataSaveSuccess() {
        this.hmacSavedToMetadata = true;
        this.showToast(
            'Success',
            'HMAC key has been saved to metadata successfully.',
            'success'
        );
        
        this.hmacKey = '';
    }
    
    handleMetadataSaveError(errorMessage) {
        this.showToast(
            'Error',
            'Failed to save HMAC key: ' + (errorMessage || 'Unknown error'),
            'error'
        );
    }

    async handleTestWebhook() {
        if (!this.webhookSetupResult?.webhookId) {
            this.showToast('Error', 'No webhook ID available for testing.', 'error');
            return;
        }

        this.isLoading = true;

        try {
            const result = await testWebhook({ webhookId: this.webhookSetupResult.webhookId });
            
            if (result.isSuccess) {
                this.showToast(
                    'Webhook Test Successful',
                    'Webhook test completed successfully. Your webhook is working properly.',
                    'success'
                );
            } else {
                this.showToast(
                    'Webhook Test Failed',
                    result.errorMessage || 'Webhook test failed. Please check your configuration.',
                    'error'
                );
            }
        } catch (error) {
            this.showToast(
                'Webhook Test Error',
                error.message || 'An error occurred while testing the webhook.',
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleCopyHmacKey() {
        if (this.hmacKey) {
            navigator.clipboard.writeText(this.hmacKey).then(() => {
                this.showToast('Success', 'HMAC key copied to clipboard', 'success');
            }).catch(() => {
                this.showToast('Error', 'Failed to copy HMAC key to clipboard', 'error');
            });
        }
    }
    
    isValidInput() {
        if (!this.description?.trim()) {
            this.showToast('Validation Error', 'Description is required.', 'error');
            return false;
        }
        
        if (!this.selectedEventCodes?.length) {
            this.showToast('Validation Error', 'At least one event code must be selected.', 'error');
            return false;
        }
        
        return true;
    }

    handleToggleHmacVisibility() {
        this.isHmacVisible = !this.isHmacVisible;
    }
    
    handleRefresh() {
        this.webhookSetupResult = null;
        this.setupError = '';
        this.hmacKey = '';
        this.hmacGenerationFailed = false;
        this.hmacErrorMessage = '';
        this.hmacSavedToMetadata = false;
        this.loadWebhookUrl();
    }
    
    handleError(error, title = 'Error') {
        const message = typeof error === 'string' ? error : (error.body?.message || error.message);
        this.showToast(title, message, 'error');
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    get hasSetupError() {
        return Boolean(this.setupError);
    }
    
    get webhookConfigured() {
        return this.webhookSetupResult !== null;
    }
    
    get showContent() {
        return !this.isLoading && !this.hasSetupError && !this.webhookConfigured;
    }
    
    get isSetupDisabled() {
        return this.isLoading || !this.description?.trim() || this.selectedEventCodes.length === 0;
    }
    
    get selectedEventLabels() {
        if (this.selectedEventCodes.length === 0) {
            return 'Select event types...';
        }
        if (this.selectedEventCodes.length === 1) {
            return this.selectedEventCodes[0];
        }
        return `${this.selectedEventCodes.length} events selected`;
    }
    
    get dropdownClass() {
        return this.isDropdownOpen ? 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open' : 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
    }
    
    get eventCodeOptionsWithSelection() {
        return this.eventCodeOptions.map(option => ({
            ...option,
            isSelected: this.selectedEventCodes.includes(option.value)
        }));
    }
    
    get showHmacSection() {
        return this.webhookConfigured && (this.hmacKey || this.hmacGenerationFailed || this.hmacSavedToMetadata);
    }
    
    get showHmacKey() {
        return this.hmacKey && !this.hmacSavedToMetadata;
    }
    
    get showSaveButton() {
        return this.hmacKey && !this.hmacSavedToMetadata && !this.isMetadataSaveLoading;
    }
    
    get showHmacError() {
        return this.hmacGenerationFailed && this.hmacErrorMessage;
    }

    get showTestWebhookButton() {
        return this.webhookConfigured && this.webhookSetupResult?.webhookId && this.hmacSavedToMetadata;
    }

    get hmacInputType() {
        return this.isHmacVisible ? 'text' : 'password';
    }

    get hmacVisibilityIcon() {
        return this.isHmacVisible ? 'utility:hide' : 'utility:preview';
    }

    get hmacVisibilityTitle() {
        return this.isHmacVisible ? 'Hide HMAC Key' : 'Show HMAC Key';
    }
}