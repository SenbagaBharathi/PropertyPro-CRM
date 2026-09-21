trigger OpportunityTrigger on Opportunity (before update) {
    OpportunityTriggerHandler.preventDoubleSellOnClosedWon(Trigger.new, Trigger.oldMap);
}