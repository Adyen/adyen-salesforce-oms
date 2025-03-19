trigger OrderSummaryCreatedEventTrigger on OrderSummaryCreatedEvent (after insert) {
    OrderSummaryCreatedEventHandler.handleAfterInsert(Trigger.new);
}