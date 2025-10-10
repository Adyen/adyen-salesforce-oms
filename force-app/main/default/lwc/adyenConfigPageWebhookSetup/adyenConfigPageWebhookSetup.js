import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe } from 'lightning/empApi';
import getWebhookUrl from '@salesforce/apex/AdyenWebhookSetupController.getWebhookUrl';
import setupWebhook from '@salesforce/apex/AdyenWebhookSetupController.setupWebhook';
import updateWebhook from '@salesforce/apex/AdyenWebhookSetupController.updateWebhook';
import saveWebhookDataToMetadata from '@salesforce/apex/AdyenWebhookSetupController.saveWebhookDataToMetadata';
import checkExistingWebhook from '@salesforce/apex/AdyenWebhookSetupController.checkExistingWebhook';
import testWebhook from '@salesforce/apex/AdyenWebhookSetupController.testWebhook';
import getPackageNamespace from '@salesforce/apex/AdyenCustomMetadataService.getPackageNamespace';

const METADATA_UPDATE_TIMEOUT = 30000;

export default class AdyenConfigPageWebhookSetup extends LightningElement {
    @api accountSetupContext;
    
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
    
    webhookId = '';
    existingWebhookFound = false;
    isUpdateMode = false;
    showWebhookExistsDialog = false;
    existingWebhookDetails = null;
    showWebhookDetails = false;
    
    showLevelMismatchDialog = false;
    levelMismatchDetails = null;
    
    channelName;
    subscription = null;
    timeoutId = null;
    pendingDeploymentId = '';
    deploymentTimedOut = false;
    isMetadataSaveLoading = false;
    namespace = '';

    eventCodeOptions = [
        { label: 'CAPTURE', value: 'CAPTURE' },
        { label: 'CAPTURE_FAILED', value: 'CAPTURE_FAILED' },
        { label: 'REFUND', value: 'REFUND' },
        { label: 'REFUND_FAILED', value: 'REFUND_FAILED' },
        { label: 'CANCELLATION', value: 'CANCELLATION' },
        { label: 'AUTHORISATION', value: 'AUTHORISATION' }
    ];

    get isCompanySetup() {
        return this.accountSetupContext?.setupType === 'company';
    }

    get setupType() {
        return this.isCompanySetup ? 'company' : 'merchant';
    }
    
    async connectedCallback() {
        this.loadWebhookUrl();
        await this.initializeEventChannel();
        this.checkForExistingWebhook();
    }
    
    disconnectedCallback() {
        this.unsubscribeFromHmacDeploymentEvents();
        this.clearTimeout();
    }

    async initializeEventChannel() {
        try {
            this.namespace = await getPackageNamespace();
            const eventName = 'Adyen_Metadata_Deployment_Result__e';
            this.channelName = this.namespace ? `/event/${this.namespace}__${eventName}` : `/event/${eventName}`;
            this.subscribeToHmacDeploymentEvents();
        } catch (error) {
            this.handleError(error, 'Error initializing event channel');
        }
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
        const nsPrefix = this.namespace ? `${this.namespace}__` : '';

        const deploymentIdField = `${nsPrefix}Deployment_Id__c`;
        const isSuccessField = `${nsPrefix}Is_Success__c`;
        const errorMessageField = `${nsPrefix}Error_Message__c`;

        if (eventData[deploymentIdField] === this.pendingDeploymentId) {
            this.clearTimeout();
            this.isMetadataSaveLoading = false;
            this.pendingDeploymentId = '';
            
            if (eventData[isSuccessField]) {
                this.handleMetadataSaveSuccess();
            } else {
                this.handleMetadataSaveError(eventData[errorMessageField]);
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
                    'Taking Longer Than Expected',
                    'The custom metadata update is still processing. You can continue with other setup steps.',
                    'warning'
                );
                this.scrollToManualUpdateInstructions();
            }
        }, METADATA_UPDATE_TIMEOUT);
    }
    
    clearTimeout() {
        if (this.timeoutId) {
            clearTimeout(this.timeoutId);
            this.timeoutId = null;
        }
    }

    scrollToManualUpdateInstructions() {
        Promise.resolve().then(() => {
            const container = this.template.querySelector('[data-id="instructions-container"]');
            const target = this.template.querySelector('[data-id="manual-update-section"]');
            if (container && target) {
                container.scrollTop = target.offsetTop;
            }
        });
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
            let result;
            if (this.isUpdateMode && this.webhookId) {
                result = await updateWebhook({
                    description: this.description,
                    eventCodes: this.selectedEventCodes,
                    webhookId: this.webhookId,
                    setupType: this.setupType
                });
            } else {
                result = await setupWebhook({
                    description: this.description,
                    eventCodes: this.selectedEventCodes,
                    setupType: this.setupType
                });
            }
            
            if (result.isSuccess) {
                this.webhookSetupResult = result;
                this.hmacKey = result.hmacKey || '';
                this.webhookId = result.webhookId || '';
                this.hmacGenerationFailed = result.hmacGenerationFailed || false;
                this.hmacErrorMessage = result.hmacErrorMessage || '';
                
                let toastMessage = this.isUpdateMode 
                    ? 'Webhook has been successfully updated' 
                    : 'Webhook has been successfully configured';
                if (this.hmacGenerationFailed) {
                    toastMessage += ', but HMAC generation failed';
                } else if (this.hmacKey) {
                    toastMessage += ' with HMAC key generated';
                }
                
                this.showToast(
                    this.isUpdateMode ? 'Webhook Update Successful' : 'Webhook Setup Successful',
                    toastMessage,
                    this.hmacGenerationFailed ? 'warning' : 'success'
                );
            } else {
                this.setupError = this.enhanceErrorMessage(result.errorMessage);
                this.handleError(result.errorMessage, this.isUpdateMode ? 'Update Failed' : 'Setup Failed');
            }
        } catch (error) {
            this.setupError = this.enhanceErrorMessage(error.message);
            this.handleError(error, this.isUpdateMode ? 'Update Failed' : 'Setup Failed');
        } finally {
            this.isLoading = false;
        }
    }
    
    async handleSaveToMetadata() {
        if (!this.hmacKey) {
            this.showToast('Error', 'No HMAC key available to save.', 'error');
            return;
        }
        
        if (!this.webhookId) {
            this.showToast('Error', 'No webhook ID available to save.', 'error');
            return;
        }
        
        this.isMetadataSaveLoading = true;
        this.deploymentTimedOut = false;
        
        try {
            const deploymentId = await saveWebhookDataToMetadata({ 
                hmacKey: this.hmacKey, 
                webhookId: this.webhookId
            });
            
            this.pendingDeploymentId = deploymentId;
            this.startTimeout();
            
            this.showToast(
                'Webhook Data Save In Progress',
                'Saving webhook data to metadata. This may take a moment.',
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
            'The webhook data has been saved to metadata successfully.',
            'success'
        );
        
        this.hmacKey = '';
    }
    
    handleMetadataSaveError(errorMessage) {
        this.showToast(
            'Error',
            'Failed to save webhook data to metadata: ' + (errorMessage || 'Unknown error'),
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
            const result = await testWebhook({
                webhookId: this.webhookSetupResult.webhookId,
                setupType: this.setupType
            });
            if (result.isSuccess) {
                this.showToast(
                    'Webhook Test Successful',
                    'Webhook test completed successfully. Your webhook is working properly. You can continue with next steps.',
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
            this.copyToClipboard(
                this.hmacKey,
                'HMAC key copied to clipboard',
                'Failed to copy HMAC key'
            );
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
        const enhancedMessage = this.enhanceErrorMessage(message);
        this.showToast(title, enhancedMessage, 'error');
    }
    
    enhanceErrorMessage(message) {
        if (message?.toLowerCase().includes('unauthorized') || message?.toLowerCase().includes('forbidden')) {
            return `${message}. Please check your Management API key and ensure it has the correct permissions.`;
        }
        if (message?.toLowerCase().includes('invalid webhook information provided') && 
            !message?.toLowerCase().includes('failed to retrieve')) {
            return `${message.replace(/\.$/, '')} or insufficient permissions.`;
        }
        return message;
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
        return this.hmacKey && !this.hmacSavedToMetadata && !this.isMetadataSaveLoading && !this.deploymentTimedOut;
    }
    
    get showHmacError() {
        return this.hmacGenerationFailed && this.hmacErrorMessage;
    }

    get showTestWebhookButton() {
        return this.webhookConfigured && 
               this.webhookSetupResult?.webhookId && 
               (this.hmacSavedToMetadata || this.deploymentTimedOut) &&
               !this.isCompanySetup;
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

    async checkForExistingWebhook() {
        try {
            const result = await checkExistingWebhook({
                setupType: this.setupType
            });
            
            if (result.webhookExists && result.webhookId) {
                this.existingWebhookFound = true;
                this.webhookId = result.webhookId;
                this.existingWebhookDetails = result;
                
                if (result.isLevelMismatch) {
                    this.levelMismatchDetails = result;
                    this.showLevelMismatchDialog = true;
                    this.isUpdateMode = false;
                } else {
                    this.isUpdateMode = true;
                    this.showWebhookExistsDialog = true;
                    
                    if (result.webhookDescription) {
                        this.description = result.webhookDescription;
                    }
                    if (result.webhookEventCodes && result.webhookEventCodes.length > 0) {
                        this.selectedEventCodes = result.webhookEventCodes;
                    }
                }
            }
        } catch (error) {
            this.handleError(error);
        }
    }

    handleContinueWithUpdate() {
        this.showWebhookExistsDialog = false;
        this.showToast(
            'Ready to Update',
            'You can now modify the webhook configuration below.',
            'info'
        );
    }

    handleToggleWebhookDetails() {
        this.showWebhookDetails = !this.showWebhookDetails;
    }

    handleDismissDialog() {
        this.showWebhookExistsDialog = false;
    }

    get setupButtonLabel() {
        return this.isUpdateMode ? 'Update Webhook' : 'Setup Webhook';
    }

    get webhookIdDisplay() {
        return this.webhookId || this.webhookSetupResult?.webhookId;
    }

    get showWebhookId() {
        return this.webhookConfigured && this.webhookIdDisplay;
    }

    get webhookDetailsToggleIcon() {
        return this.showWebhookDetails ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get webhookDetailsToggleLabel() {
        return this.showWebhookDetails ? 'Hide Details' : 'Show Details';
    }

    get existingWebhookEventCodesDisplay() {
        return this.existingWebhookDetails?.webhookEventCodes?.join(', ') || 'No events configured';
    }

    handleCopyWebhookId() {
        if (this.webhookIdDisplay) {
            this.copyToClipboard(
                this.webhookIdDisplay,
                'Webhook ID copied to clipboard',
                'Failed to copy webhook ID'
            );
        }
    }

    copyToClipboard(content, successMessage, errorMessage) {
        if (navigator.clipboard && window.isSecureContext) {
            navigator.clipboard.writeText(content)
                .then(() => {
                    this.showToast('Success', successMessage, 'success');
                })
                .catch(() => {
                    this.showToast('Error', errorMessage, 'error');
                });
        } else {
            const el = document.createElement('textarea');
            el.value = content;
            el.setAttribute('readonly', '');
            el.style.position = "fixed";
            el.style.left = "-999999px";
            el.style.top = "-999999px";
            document.body.appendChild(el);
            el.focus();
            el.select();
            try {
                const successful = document.execCommand('copy');
                if (successful) {
                    this.showToast('Success', successMessage, 'success');
                } else {
                    this.showToast('Error', errorMessage, 'error');
                }
            } catch (err) {
                this.showToast('Error', errorMessage, 'error');
            } finally {
                document.body.removeChild(el);
            }
        }
    }

    handleCreateNewWebhook() {
        this.showLevelMismatchDialog = false;
        this.existingWebhookFound = false;
        this.isUpdateMode = false;
        this.webhookId = '';
        
        this.showToast(
            'Creating New Webhook',
            `A new webhook will be created at the ${this.setupTypeLabel} level.`,
            'info'
        );
    }

    closeLevelMismatchDialog() {
        this.showLevelMismatchDialog = false;
        this.levelMismatchDetails = null;
    }
    
    get isMerchantSetup() {
        return this.accountSetupContext?.setupType === 'merchant';
    }
    
    get companyName() {
        return this.accountSetupContext?.companyName;
    }
    
    get merchantAccountId() {
        return this.accountSetupContext?.merchantAccountId;
    }
    
    get setupTypeLabel() {
        if (this.isCompanySetup) {
            return 'Company Account';
        } else if (this.isMerchantSetup) {
            return 'Merchant Account';
        }
        return 'Account';
    }

    get levelMismatchMessage() {
        if (!this.levelMismatchDetails) return '';
        
        const requestedType = this.levelMismatchDetails.requestedSetupType;
        const detectedType = this.levelMismatchDetails.detectedWebhookLevel;
        
        if (requestedType === 'company' && detectedType === 'merchant') {
            return 'An existing webhook was found at the merchant account level. You have selected to set up a webhook at the company level.';
        } else if (requestedType === 'merchant' && detectedType === 'company') {
            return 'An existing webhook was found at the company level. You have selected to set up a webhook at the merchant account level.';
        }
        return 'Webhook level mismatch detected.';
    }

    get existingWebhookLevel() {
        return this.levelMismatchDetails?.detectedWebhookLevel === 'company' ? 'Company' : 'Merchant';
    }

    get currentSelectionLevel() {
        return this.setupTypeLabel;
    }
}