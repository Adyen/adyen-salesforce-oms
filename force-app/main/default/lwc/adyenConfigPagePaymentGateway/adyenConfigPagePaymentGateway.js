import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExistingPaymentGateways from '@salesforce/apex/AdyenConfigPageController.getExistingPaymentGateways';
import createPaymentGateways from '@salesforce/apex/AdyenConfigPageController.createPaymentGateways';

export default class AdyenConfigPagePaymentGateway extends LightningElement {
    showSpinner = false;
    @track standardGateway = {
        gatewayName: 'Adyen',
        externalReference: 'Adyen_Component'
    };
    @track posGateway = {
        gatewayName: 'AdyenPos',
        externalReference: 'Adyen_POS'
    };
    @track existingGateways = [];
    hasStandardGateway = false;
    hasPosGateway = false;
    posGatewayEnabled = false;
    
    stepName = 'paymentGateway';
    
    get isPosGatewayDisabled() {
        return !this.posGatewayEnabled;
    }
    
    get showNoGatewaysNeeded() {
        return this.hasStandardGateway && this.hasPosGateway;
    }
    
    gatewayColumns = [
        { label: 'Gateway Name', fieldName: 'PaymentGatewayName', type: 'text' },
        { label: 'External Reference', fieldName: 'ExternalReference', type: 'text' },
        { label: 'Status', fieldName: 'Status', type: 'text' }
    ];

    async connectedCallback() {
        await this.loadExistingGateways();
    }

    async loadExistingGateways() {
        this.showSpinner = true;
        try {
            const data = await getExistingPaymentGateways();
            this.existingGateways = data;
            this.hasStandardGateway = this.existingGateways.some(
                gateway => gateway.ExternalReference === this.standardGateway.externalReference
            );
            this.hasPosGateway = this.existingGateways.some(
                gateway => gateway.ExternalReference === this.posGateway.externalReference
            );
            if (this.hasStandardGateway && !this.hasPosGateway) {
                this.posGatewayEnabled = true;
            }
        } catch (error) {
            this.existingGateways = [];
            this.handleError(error);
        } finally {
            this.showSpinner = false;
        }
    }
    
    handleStandardGatewayNameChange(event) {
        this.standardGateway.gatewayName = event.target.value;
    }
    
    handlePosGatewayNameChange(event) {
        this.posGateway.gatewayName = event.target.value;
    }
    
    handlePosGatewayToggle(event) {
        this.posGatewayEnabled = event.target.checked;
    }
    
    async handleSubmit() {
    this.showSpinner = true;
    try {
        const standardName = this.standardGateway.gatewayName.trim();
        const posName = this.posGateway.gatewayName.trim();
        
        const gatewayInputs = [];
        if (!this.hasStandardGateway) {
            gatewayInputs.push({
                gatewayName: standardName,
                externalReference: this.standardGateway.externalReference
            });
        }
        
        if (this.posGatewayEnabled && !this.hasPosGateway) {
            gatewayInputs.push({
                gatewayName: posName,
                externalReference: this.posGateway.externalReference
            });
        }
        const result = await createPaymentGateways({ paymentGatewayInputs: gatewayInputs });
        await this.handleSuccess(result);

        } catch(error) {
            this.handleError(error);
        }
           
    }
    
    async handleSuccess(result) {
        this.showSpinner = false;
        await this.loadExistingGateways();
        this.showToast('Success', `${result.length} payment gateway(s) created successfully.`, 'success');
        this.dispatchStepCompleteEvent(true);
        
    }
    
    handleError(error) {
        this.showSpinner = false;
        const errorMessage = error.body?.message || 'An unknown error occurred.';
        this.showToast('Error', errorMessage, 'error');
        
    }
    
    handleSkip() {
        this.dispatchStepCompleteEvent(true);
    }
    
    dispatchStepCompleteEvent(success) {
        const stepCompleteEvent = new CustomEvent('stepcomplete', {
            detail: {
                step: this.stepName,
                success: success
            }
        });
        this.dispatchEvent(stepCompleteEvent);
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
    
}