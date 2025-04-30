trigger Voyage_Trigger on Voyage__c (before update) {
    Map<Id, Voyage__c> triggerNewMap = new Map<Id, Voyage__c>(Trigger.new);
    Map<Id,Voyage__c> triggerOldMap = new Map<Id, Voyage__c>(Trigger.Old);
    
    List<Id> travelOfferingIds = new List<Id>();
    List<TravelOffering__c> travelOfferings = new List<TravelOffering__c>();
    List<Case> caseList = new List<Case>();
    Set<Id> voyageIdSet = new Set<Id>();
    Map<Id, Case> voyageToCaseMap = new Map<Id,Case>();
    List<Compensation__c> newCompensationList = new List<Compensation__c>();

    Map<Id, String> refundPercentMap = new Map<Id, String>();
	Map<Id, List<Voyage__c>> TravelOfferingToVoyageMap = new Map<Id, List<Voyage__c>>();
    	
    for(Voyage__c ticket: Trigger.new){
        if(ticket.IsRefundRequested__c == true && triggerNewMap.get(ticket.Id).IsRefundRequested__c != triggerOldMap.get(ticket.Id).IsRefundRequested__c){
            travelOfferingIds.add(ticket.Travel_Offering__c);
            voyageIdSet.add(ticket.Id);
            if(!TravelOfferingToVoyageMap.containsKey(ticket.Travel_Offering__c)){
                TravelOfferingToVoyageMap.put(ticket.Travel_Offering__c, new List<Voyage__c>());
            }
            TravelOfferingToVoyageMap.get(ticket.Travel_Offering__c).add(ticket);
        }
    }
    
    travelOfferings = [SELECT Id, Actual_Start_DateTime__c, Delay_Duration_Minutes__c,Price__c  FROM TravelOffering__c WHERE Id IN :travelOfferingIds];
    if(voyageIdSet.size() > 0)
        caseList = [Select Id, Voyage__c, Voyage__r.Contact__r.Email FROM Case where Voyage__c In :voyageIdSet];
    for(Case c: caseList)
        voyageToCaseMap.put(c.Voyage__c, c);
    
    for(TravelOffering__c travelOffer :travelOfferings){
        if(travelOffer.Actual_Start_DateTime__c == null){
            throw new IllegalArgumentException('Actual_Start_DateTime__c cannot be null to calculate delay and refund amount');
        }
        if(travelOffer.Delay_Duration_Minutes__c != null && travelOffer.Delay_Duration_Minutes__c > 0){
            Map<String, Object> Params = new Map<String, Object>();
            Params.put('TravelOffering', travelOffer);
            Flow.Interview.Invoke_Delay_Refund_Prompt_Template refundPercent = new Flow.Interview.Invoke_Delay_Refund_Prompt_Template (Params);
            refundPercent.start();
            String Percent =(string)refundPercent.getvariableValue('RefundPercentage');
            System.debug('RefundPercentage: ' + Percent);
            if (Percent != null && Percent.contains('%')) {
                Percent = Percent.replace('%', '');
            }

            refundPercentMap.put(travelOffer.Id, Percent + '@@' + travelOffer.Price__c);

        }
    }
    for(Id travelOffering: TravelOfferingToVoyageMap.keySet()){
        for(Voyage__c voyage : TravelOfferingToVoyageMap.get(travelOffering)){
            if(refundPercentMap.containsKey(travelOffering)){
                List<String> refuntAmt = refundPercentMap.get(travelOffering).split('@@');
               	voyage.RefundAmount__c = Integer.valueOf(refuntAmt[1]) * Integer.valueOf(refuntAmt[0])/100;
                System.debug('Refund Amount: ' + voyage.RefundAmount__c);
                // Create compensation record
                if(voyage.RefundAmount__c > 0){
                    Compensation__c comp = new Compensation__c();
                    comp.Customer__c  = voyage.Contact__c;
                    comp.Case__c = voyageToCaseMap.get(voyage.Id).Id;
                    comp.Compensation_Amount__c = voyage.RefundAmount__c;
                    comp.Status__c = 'Pending';
                    comp.Travel_Offering__c = travelOffering;
                    comp.Voyage__c = voyage.Id;
                    newCompensationList.add(comp);
                }
            }
        }
    }
    System.debug('newCompensationList: ' + newCompensationList);
    if(newCompensationList.size() > 0) insert newCompensationList;
}