@isTest
private class BookingTriggerTest {

    // Helper: creates a Property__c record with a given status
    private static Property__c createProperty(String status) {
        Property__c prop = new Property__c(
            Status__c = status
        );
        insert prop;
        return prop;
    }

    @isTest
    static void testBookingSucceeds_WhenPropertyAvailable() {
        Property__c prop = createProperty('Available');

        Test.startTest();
        Booking__c booking = new Booking__c(
            Property__c = prop.Id,
            Status__c = 'Confirmed'
        );
        insert booking;
        Test.stopTest();

        List<Booking__c> bookings = [SELECT Id, Status__c FROM Booking__c WHERE Property__c = :prop.Id];
        System.assertEquals(1, bookings.size(), 'Booking should be created when property is Available');
    }

    @isTest
    static void testDoubleBookingBlocked_WhenConfirmedBookingExists() {
        Property__c prop = createProperty('Available');

        // First confirmed booking goes through
        Booking__c firstBooking = new Booking__c(
            Property__c = prop.Id,
            Status__c = 'Confirmed'
        );
        insert firstBooking;

        Test.startTest();
        Booking__c secondBooking = new Booking__c(
            Property__c = prop.Id,
            Status__c = 'Confirmed'
        );

        Boolean exceptionThrown = false;
        try {
            insert secondBooking;
        } catch (DmlException e) {
            exceptionThrown = true;
            System.assert(
                e.getMessage().contains('already') || e.getMessage().contains('booked') || e.getMessage().contains('sold'),
                'Expected a double-booking validation error, got: ' + e.getMessage()
            );
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Second Confirmed booking on same property should be blocked');
    }

    @isTest
    static void testBookingBlocked_WhenPropertyAlreadySold() {
        Property__c prop = createProperty('Sold');

        Test.startTest();
        Booking__c booking = new Booking__c(
            Property__c = prop.Id,
            Status__c = 'Confirmed'
        );

        Boolean exceptionThrown = false;
        try {
            insert booking;
        } catch (DmlException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Booking should be blocked when Property status is Sold');
    }
    @isTest
static void testBulkBookingInsert() {
    List<Property__c> properties = new List<Property__c>();
    for (Integer i = 0; i < 200; i++) {
        properties.add(new Property__c(
            Status__c = 'Available'
        ));
    }
    insert properties;
    System.assertEquals(200, properties.size(), 'Properties list should have 200 before insert');

    List<Booking__c> bookings = new List<Booking__c>();
    for (Property__c p : properties) {
        bookings.add(new Booking__c(
            Property__c = p.Id,
            Status__c = 'Confirmed'
        ));
    }
    System.assertEquals(200, bookings.size(), 'Bookings list should have 200 before insert');

    Test.startTest();
    insert bookings;
    Test.stopTest();

    List<Booking__c> allBookings = [SELECT Id, Status__c, Property__c FROM Booking__c];
    System.assertEquals(200, allBookings.size(), 'Total bookings actually inserted: ' + allBookings.size());
}
   

    @isTest
    static void testBookingAllowed_WhenPreviousBookingNotConfirmed() {
        Property__c prop = createProperty('Available');

        // Existing booking is not Confirmed (e.g. Cancelled) — should not block a new one
        Booking__c cancelledBooking = new Booking__c(
            Property__c = prop.Id,
            Status__c = 'Cancelled'
        );
        insert cancelledBooking;

        Test.startTest();
        Booking__c newBooking = new Booking__c(
            Property__c = prop.Id,
            Status__c = 'Confirmed'
        );
        insert newBooking;
        Test.stopTest();

        List<Booking__c> confirmedBookings = [
            SELECT Id FROM Booking__c WHERE Property__c = :prop.Id AND Status__c = 'Confirmed'
        ];
        System.assertEquals(1, confirmedBookings.size(), 'New Confirmed booking should succeed when prior booking is not Confirmed');
    }
}