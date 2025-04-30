trigger Compensation_Trigger on Compensation__c (before update) {
    
    Map<Id, Compensation__c> triggerNewMap = new Map<Id, Compensation__c>(Trigger.new);
    Map<Id, Compensation__c> triggerOldMap = new Map<Id, Compensation__c>(Trigger.Old);
    
    List<Id> compensationIds = new List<Id>();
    
    for(Compensation__c compensation: Trigger.new){
        if(triggerOldMap.get(compensation.Id).Status__c == 'Pending' && triggerNewMap.get(compensation.Id).Status__c == 'Approved'){
        	compensationIds.add(compensation.Id);
        }
    }
    
    List<Compensation__c> compensations = [SELECT Id, Customer__r.Email, Compensation_Amount__c FROM Compensation__c];
    
    List<String> emailAddresses = new List<String>();
    Map<String, Compensation__c> emailToCompensationMap = new Map<String, Compensation__c>();
    
    for(Compensation__c compensation: compensations){
        emailAddresses.add(compensation.Customer__r.Email);
        emailToCompensationMap.put(compensation.Customer__r.Email, compensation);
    }
    
    for(String emailAddress: emailAddresses){
        // Mail the customer refund is initiated
        System.debug('emailAddress: ' + emailAddress);
        String company = 'Wanderlust Travel';
        String subject = 'Refund Initiated for Your Recent Transaction';
        String mailTo = 'support@wanderlust.com';
        String body = '<html><body style=\'font-family: Arial, sans-serif; color: #333;\'>'
            + '<p>Dear <strong>' + emailAddress + '</strong>,</p>'
            + '<p>We hope this message finds you well.</p>'
            + '<p>This is to inform you that the refund for your recent transaction with us has been successfully initiated. Please find the details below:</p>'
            + '<table style=\'border-collapse: collapse; margin: 10px 0;\'>'
            + '<tr><td style=\'padding: 8px; font-weight: bold;\'>Transaction ID:</td><td style=\'padding: 8px;\'>'+ UUID.randomUUID() +'</td></tr>'
            + '<tr><td style=\'padding: 8px; font-weight: bold;\'>Refund Amount:</td><td style=\'padding: 8px;\'>₹'+ emailToCompensationMap.get(emailAddress).Compensation_Amount__c +'</td></tr>'
            + '<tr><td style=\'padding: 8px; font-weight: bold;\'>Initiated On:</td><td style=\'padding: 8px;\'>'+ Date.today() +'</td></tr>'
            + '<tr><td style=\'padding: 8px; font-weight: bold;\'>Payment Mode:</td><td style=\'padding: 8px;\'>Bank Transfer</td></tr>'
            + '</table>'
            + '<p>Please note that depending on your payment method and bank, the refund may take <strong>3–7 business days</strong> to reflect in your account.</p>'
            + '<p>If you have any questions or need further assistance, please feel free to contact us at <a href=\'mailto:'+ mailTo +'\'>'+ mailTo +'</a>.</p>'
            + '<p>Thank you for your patience and for choosing <strong>' + company + '</strong>.</p>'
            + '<p>Warm regards,<br>'
            + '<strong>Ed</strong><br>'
            + 'Customer Support<br>'
            + company + '<br>'
            + '+91 9123456781</p>'
            + '</body></html>';
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { emailAddress });
        mail.setSubject(subject);

        mail.setHtmlBody(body); 
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
                
}