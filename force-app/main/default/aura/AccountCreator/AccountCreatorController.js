({
    createAccount : function(component, event, helper) {

        var action = component.get("c.createAccount");

        action.setParams({
            Name: component.get("v.accountName"),
            Phone: component.get("v.phone"),
            Type: component.get("v.type"),
            Rating: component.get("v.rating"),
            DOB: null,
            Email: null,
            BillingStreet: null,
            BillingCity: null,
            BillingState: null,
            BillingPostalCode: null,
            BillingCountry: null,
            ShippingStreet: null,
            ShippingCity: null,
            ShippingState: null,
            ShippingPostalCode: null,
            ShippingCountry: null,
            CustomerPriority: null,
            SLA: null,
            SLAExpirationDate: null
        });

        action.setCallback(this, function(response) {

            var state = response.getState();

            if (state === "SUCCESS") {

                component.set("v.message",
                    "Account Created Successfully: " +
                    response.getReturnValue());

            } else {

                var errors = response.getError();

                component.set("v.message",
                    "Error: " + errors[0].message);
            }
        });

        $A.enqueueAction(action);
    }
})