trigger BookingTrigger on Booking__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            BookingTriggerHandler.preventDoubleSell(Trigger.new);
        }
    }
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            BookingTriggerHandler.updatePropertyStatus(Trigger.new, Trigger.oldMap);
        }
    }
}