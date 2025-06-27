import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getWebhookUrl from '@salesforce/apex/AdyenWebhookSetupController.getWebhookUrl';
import setupWebhook from '@salesforce/apex/AdyenWebhookSetupController.setupWebhook';

export default class AdyenConfigPageWebhookSetup extends LightningElement {
    description = 'Adyen Webhook for Salesforce OMS';
    selectedEventCodes = ['CAPTURE', 'CAPTURE_FAILED', 'REFUND', 'REFUND_FAILED'];
    webhookUrl = '';
    isLoading = false;
    webhookSetupResult = null;
    setupError = '';
    isDropdownOpen = false;

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
        
        try {
            const result = await setupWebhook({
                description: this.description,
                eventCodes: this.selectedEventCodes
            });
            
            if (result.isSuccess) {
                this.webhookSetupResult = result.webhookResponse;
                this.showToast(
                    'Webhook Setup Successful',
                    'Webhook has been successfully configured',
                    'success'
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
    
    handleRefresh() {
        this.webhookSetupResult = null;
        this.setupError = '';
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
}