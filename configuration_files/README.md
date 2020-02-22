The NN-global_conf.json files were copied from (Latest commit 551afce  on 14 Aug 2018):
https://github.com/TheThingsNetwork/gateway-conf

The following modifications were made to these files:

     - Add comment on top of each file containing the global configuration filename. 
       To help users to identify which region was selected.
     - Set lbt_cfg.enable = false
     - Remove the "servers" parameter and its value. The servers parameter are not used by the Semtech lora_gateway and packet_forwarder.

NN refers to a specific region (AS1, AS2, AU, BR, CN, EU, IN, KR, RU and US) where a specific frequency plan is used.


Added custom configuration for the RAK831 operating in Brazil by AdailSilva.
