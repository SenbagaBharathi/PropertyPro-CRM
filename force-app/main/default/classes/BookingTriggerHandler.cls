public with sharing class BookingTriggerHandler {

    // Before insert/update: block double-selling
    public static void preventDoubleSell(List<Booking__c> newBookings) {
        Set<Id> propertyIds = new Set<Id>();
        for (Booking__c b : newBookings) {
            if (b.Property__c != null) {
                propertyIds.add(b.Property__c);
            }
        }
        if (propertyIds.isEmpty()) return;

        // CRUD check before querying Property__c
        if (!Schema.sObjectType.Property__c.isAccessible()
            || !Schema.sObjectType.Property__c.fields.Status__c.isAccessible()) {
            return;
        }

        // Check Property status
        Map<Id, Property__c> propertyMap = new Map<Id, Property__c>(
            [SELECT Id, Status__c FROM Property__c WHERE Id IN :propertyIds]
        );

        // CRUD check before querying Booking__c
        if (!Schema.sObjectType.Booking__c.isAccessible()
            || !Schema.sObjectType.Booking__c.fields.Property__c.isAccessible()
            || !Schema.sObjectType.Booking__c.fields.Status__c.isAccessible()) {
            return;
        }

        // Check existing Confirmed bookings per property
        Map<Id, Integer> confirmedCountByProperty = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Property__c propId, COUNT(Id) cnt
            FROM Booking__c
            WHERE Property__c IN :propertyIds AND Status__c = 'Confirmed'
            GROUP BY Property__c
        ]) {
            confirmedCountByProperty.put((Id) ar.get('propId'), (Integer) ar.get('cnt'));
        }

        for (Booking__c b : newBookings) {
            if (b.Property__c == null) continue;
            Property__c prop = propertyMap.get(b.Property__c);

            if (prop != null && (prop.Status__c == 'Sold' || prop.Status__c == 'Booked')) {
                b.addError('This property is already ' + prop.Status__c + ' and cannot be booked again.');
                continue;
            }

            Integer confirmedCount = confirmedCountByProperty.get(b.Property__c);
            if (confirmedCount != null && confirmedCount > 0 && b.Status__c != 'Confirmed') {
                // allow if THIS record is the confirmed one on update; otherwise block
                b.addError('This property already has a confirmed booking.');
            }
        }
    }

    // After insert/update: sync Property status when a Booking is Confirmed
    public static void updatePropertyStatus(List<Booking__c> newBookings, Map<Id, Booking__c> oldMap) {
        Set<Id> propertyIdsToUpdate = new Set<Id>();

        for (Booking__c b : newBookings) {
            Booking__c oldB = (oldMap != null) ? oldMap.get(b.Id) : null;
            Boolean statusChangedToConfirmed =
                b.Status__c == 'Confirmed' && (oldB == null || oldB.Status__c != 'Confirmed');

            if (statusChangedToConfirmed && b.Property__c != null) {
                propertyIdsToUpdate.add(b.Property__c);
            }
        }

        if (!propertyIdsToUpdate.isEmpty()) {
            // CRUD check before updating Property__c
            if (!Schema.sObjectType.Property__c.isUpdateable()
                || !Schema.sObjectType.Property__c.fields.Status__c.isUpdateable()) {
                return;
            }

            List<Property__c> propsToUpdate = new List<Property__c>();
            for (Id propId : propertyIdsToUpdate) {
                propsToUpdate.add(new Property__c(Id = propId, Status__c = 'Booked'));
            }
            update propsToUpdate;
        }
    }
}