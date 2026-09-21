@isTest
private class OpportunityTriggerTest {

    @TestSetup
    static void setup() {
        insert new List<Property__c>{
            new Property__c(Status__c = 'Available'),
            new Property__c(Status__c = 'Booked'),
            new Property__c(Status__c = 'Sold')
        };
    }

    private static Opportunity newOppFor(String propertyStatus, String oppName) {
        Property__c prop = [SELECT Id FROM Property__c WHERE Status__c = :propertyStatus LIMIT 1];
        Opportunity opp = new Opportunity(
            Name = oppName,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Property__c = prop.Id
        );
        insert opp;
        return opp;
    }

    @isTest
    static void testClosedWonAllowedWhenPropertyAvailable() {
        Opportunity opp = newOppFor('Available', 'Deal - Available');

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        Opportunity result = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Closed Won', result.StageName);
    }

    @isTest
    static void testClosedWonBlockedWhenPropertyBooked() {
        Opportunity opp = newOppFor('Booked', 'Deal - Booked');

        Test.startTest();
        opp.StageName = 'Closed Won';
        Boolean errorCaught = false;
        try {
            update opp;
        } catch (DmlException e) {
            errorCaught = true;
            System.assert(e.getMessage().contains('already Booked'));
        }
        Test.stopTest();

        System.assert(errorCaught, 'Expected an error when closing won on a Booked property');
    }

    @isTest
    static void testClosedWonBlockedWhenPropertySold() {
        Opportunity opp = newOppFor('Sold', 'Deal - Sold');

        Test.startTest();
        opp.StageName = 'Closed Won';
        Boolean errorCaught = false;
        try {
            update opp;
        } catch (DmlException e) {
            errorCaught = true;
            System.assert(e.getMessage().contains('already Sold'));
        }
        Test.stopTest();

        System.assert(errorCaught, 'Expected an error when closing won on a Sold property');
    }

    @isTest
    static void testNonClosedWonStageChangeNotBlocked() {
        Opportunity opp = newOppFor('Sold', 'Deal - Stage Change');

        Test.startTest();
        opp.StageName = 'Qualification';
        update opp;
        Test.stopTest();

        Opportunity result = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Qualification', result.StageName);
    }

    @isTest
    static void testBulkClosedWonHalfBlockedHalfAllowed() {
        List<Property__c> props = new List<Property__c>();
        for (Integer i = 0; i < 200; i++) {
            props.add(new Property__c(
                Status__c = Math.mod(i, 2) == 0 ? 'Available' : 'Sold'
                ));            
        }
        insert props;

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            opps.add(new Opportunity(
                Name = 'Bulk Deal ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(10),
                Property__c = props[i].Id
            ));
        }
        insert opps;

        for (Opportunity o : opps) {
            o.StageName = 'Closed Won';
        }

        Test.startTest();
        Database.SaveResult[] results = Database.update(opps, false);
        Test.stopTest();

        Integer successCount = 0;
        Integer failCount = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successCount++;
            } else {
                failCount++;
            }
        }

        System.assertEquals(100, successCount, 'Opportunities on Available properties should close won');
        System.assertEquals(100, failCount, 'Opportunities on Sold properties should be blocked');
    }
}