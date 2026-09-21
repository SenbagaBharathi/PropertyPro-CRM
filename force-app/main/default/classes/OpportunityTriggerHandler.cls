public class OpportunityTriggerHandler {

    /**
     * Blocks an Opportunity from moving into Closed Won if its linked
     * Property__c is already Booked or Sold (prevents double-selling).
     * Only fires for records actually transitioning INTO Closed Won,
     * not on every edit of an already-won/lost deal.
     */
    public static void preventDoubleSellOnClosedWon(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        Set<Id> propertyIds = new Set<Id>();

        for (Opportunity opp : newOpps) {
            if (isMovingToClosedWon(opp, oldOppMap.get(opp.Id)) && opp.Property__c != null) {
                propertyIds.add(opp.Property__c);
            }
        }

        if (propertyIds.isEmpty()) {
            return;
        }

        Map<Id, Property__c> propertyMap = new Map<Id, Property__c>(
            [SELECT Id, Status__c FROM Property__c WHERE Id IN :propertyIds]
        );

        for (Opportunity opp : newOpps) {
            if (!isMovingToClosedWon(opp, oldOppMap.get(opp.Id)) || opp.Property__c == null) {
                continue;
            }

            Property__c prop = propertyMap.get(opp.Property__c);
            if (prop != null && (prop.Status__c == 'Booked' || prop.Status__c == 'Sold')) {
                opp.addError('This property is already ' + prop.Status__c + '. This Opportunity cannot be closed as Won.');
            }
        }
    }

    private static Boolean isMovingToClosedWon(Opportunity newOpp, Opportunity oldOpp) {
        return newOpp.StageName == 'Closed Won' && oldOpp.StageName != 'Closed Won';
    }
}