char g_sTestItemModel[] = "models/weapons/v_knife_css_inspect.mdl";


public QuestItems_OnPluginStart(){

}

int g_QuestItemList[MAXPLAYERS+1][2];

public RewardQuest(int client, Quest quest){

    switch(quest.reward.type){
        case(Credits):{
            ServerCommand("sm_givecredits #%i %i", GetClientUserId(client), quest.reward.value);
            CPrintToChat(client, "Vous remportez {green}%d{default} crédits!\n", quest.reward.value);
            playersQuests[client] = EMPTYQUEST;
        }
        case(New_Quest):{
            CPrintToChat(client, "{green} Vous avez reçu une nouvelle quête!{default}\n");
            GiveQuestF(client, quest.reward.value);
            GenerateQuestItems(client, playersQuests[client]);
        }

        case(Shop_Item):{
            // A VOIR
            playersQuests[client] = EMPTYQUEST;
        }

        default:{
            CPrintToChat(client, "Error, RewardQuest : Unknown reward type : %d", quest.reward.type);
        }
    }

}



bool IsCorrectClient(int client, int caller){
    return (g_QuestItemList[client][1] == caller || g_QuestItemList[client][0] == caller);
}

public Action OnQuestCompletionAction(int entity, int activator, int caller, UseType type, float value){
    if(!ValidPlayer(activator)) return;

    if(!IsCorrectClient(activator, entity)) return;

    char nameBuffer[128];
    GetClientName(activator, nameBuffer, sizeof(nameBuffer));

    CPrintToChatAll("{green}%s{default} a complété la quête : {yellow}%s{default}\n", nameBuffer, playersQuests[activator].name);
    
    if(playersQuests[activator].hasSound) EmitAmbientSound(playersQuests[activator].soundName , playersQuests[activator].linkedEntity.pos);

    if(playersQuests[activator].linkedEntity.hasEffect){
        switch(playersQuests[activator].linkedEntity.effect){
            case(Fire) : {
                new fireEntity;
                if((fireEntity = CreateEntityByName("env_fire")) != -1){
                    DispatchKeyValue(fireEntity, "damagescale", "5");
                    DispatchKeyValue(fireEntity, "fireattack", "4");
                    DispatchKeyValue(fireEntity, "firesize", "64");
                    DispatchKeyValue(fireEntity, "spawnflags", "31");
                    DispatchKeyValue(fireEntity, "health", "1000");
                    DispatchSpawn(fireEntity);
                    ActivateEntity(fireEntity);
                    TeleportEntity(fireEntity, playersQuests[activator].linkedEntity.pos, NULL_VECTOR, NULL_VECTOR);
                }
            }

            case(Smoke) : {
                new smokeEntity;
                if((smokeEntity = CreateEntityByName("env_smokestack")) != -1){
                    DispatchKeyValue(smokeEntity, "BaseSpread", "20");
                    DispatchKeyValue(smokeEntity, "EndSize", "30");
                    DispatchKeyValue(smokeEntity, "InitialState", "1");
                    DispatchKeyValue(smokeEntity, "JetLength", "20");
                    DispatchKeyValue(smokeEntity, "SmokeMaterial", "particle/SmokeStack.vmt");
                    DispatchKeyValue(smokeEntity, "Speed", "30");
                    DispatchKeyValue(smokeEntity, "SpreadSpeed", "15");
                    DispatchKeyValue(smokeEntity, "StartSize", "20");
                    DispatchSpawn(smokeEntity);
                    ActivateEntity(smokeEntity);
                    TeleportEntity(smokeEntity, playersQuests[activator].linkedEntity.pos, NULL_VECTOR, NULL_VECTOR);
                }
            }

            case(Spark) : {
                new sparkEntity;
                if((sparkEntity = CreateEntityByName("env_spark")) != -1){
                    DispatchKeyValue(sparkEntity, "Magnitude", "1");
                    DispatchKeyValue(sparkEntity, "spawnflags", "64");
                    DispatchKeyValue(sparkEntity, "TrailLength", "1");
                    DispatchSpawn(sparkEntity);
                    ActivateEntity(sparkEntity);
                    TeleportEntity(sparkEntity, playersQuests[activator].linkedEntity.pos, NULL_VECTOR, NULL_VECTOR);
                }
            }

            default :{

            }
        }

    }
    
    SDKUnhook(entity, SDKHook_Use, OnQuestCompletionAction);

    if(playersQuests[activator].type == Fetch) AcceptEntityInput(g_QuestItemList[activator][0], "kill");
    if(playersQuests[activator].linkedEntity.destroy && (playersQuests[activator].type == Fetch || playersQuests[activator].type == Activate)) AcceptEntityInput(g_QuestItemList[activator][1], "kill"); 

    RewardQuest(activator, playersQuests[activator]);

    return;
}


public OnQuestCompletionForBreak(const char[] output, int caller, int activator, float delay){
	OnQuestCompletionAction(caller, activator, caller, Use_On, 0);
}

int entQuestItemCreate(int client, int ent, Quest quest) {

	new String:targetname[128];
    char rotation[128];
    //char clientIDBuffer[8];

	Format(targetname, sizeof(targetname), "questItem_%i", ent);
    Format(rotation, sizeof(rotation), "%f %f %f", quest.linkedEntity.rot[0], quest.linkedEntity.rot[1], quest.linkedEntity.rot[2]);
    //Format(clientIDBuffer, sizeof(clientIDBuffer), "%d", client); 

	if(quest.type == Fetch || quest.type == Activate) DispatchKeyValue(ent, "model", quest.linkedEntity.skin);
	DispatchKeyValue(ent, "targetname", targetname);
    DispatchKeyValue(ent, "angles", rotation);
    DispatchKeyValue(ent, "solid", "6");
    //DispatchKeyValue(ent, "pressuredelay", clientIDBuffer); //On stocke l'information de quête dans pressuredelay

	if(quest.type == Destroy){
        DispatchKeyValue(ent, "health", "50");
        DispatchKeyValue(ent, "rendercolor", "255 255 255");
    }

    DispatchSpawn(ent);
    
    if(quest.type == Destroy){
    
    SetEntPropVector(ent, Prop_Send, "m_vecMins", quest.linkedEntity.sizeOverrideMin);
    SetEntPropVector(ent, Prop_Send, "m_vecMaxs", quest.linkedEntity.sizeOverrideMax);

    }

	SetEntProp(ent, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_NONE);

	return ent;
}


int linkedButtonQuestItemCreate(int button, int ent, Quest quest){
    new String:targetname[128];

	Format(targetname, sizeof(targetname), "questItemButton_%i", button);

    DispatchKeyValue(button, "targetname", targetname);
    DispatchKeyValue(button, "min_use_angle", "0.8");
    DispatchKeyValue(button, "movedir", "0 0 0");
	DispatchKeyValue(button, "wait", "1");
    DispatchKeyValue(button, "lip", "0"); 
    DispatchKeyValue(button, "speed", "1");
    DispatchKeyValue(button, "spawnflags", "17409");

    DispatchSpawn(button);
    ActivateEntity(button);

    if(ent == -1 || (quest.linkedEntity.sizeOverrideMin[0] != 0 
    || quest.linkedEntity.sizeOverrideMin[1] != 0 
    || quest.linkedEntity.sizeOverrideMin[2] != 0 
    || quest.linkedEntity.sizeOverrideMax[0] != 0 
    || quest.linkedEntity.sizeOverrideMax[1] != 0 
    || quest.linkedEntity.sizeOverrideMax[2] != 0))

    {
        SetEntPropVector(button, Prop_Send, "m_vecMins", quest.linkedEntity.sizeOverrideMin);
        SetEntPropVector(button, Prop_Send, "m_vecMaxs", quest.linkedEntity.sizeOverrideMax);
    }

    else
    {
        float minVect[3];
        float maxVect[3];

        GetEntPropVector(ent, Prop_Send, "m_vecMins", minVect);
        GetEntPropVector(ent, Prop_Send, "m_vecMaxs", maxVect);

        minVect[0] -= 2;
        minVect[1] -= 2;
        minVect[2] -= 2;

        maxVect[0] += 2;
        maxVect[1] += 2;
        maxVect[2] += 2;

        SetEntPropVector(button, Prop_Send, "m_vecMins", minVect);
        SetEntPropVector(button, Prop_Send, "m_vecMaxs", maxVect);
    }

    SetEntProp(button, Prop_Send, "m_nSolidType", 4);
    
    return button;
}


public GenerateFetchQuestItem(int client, Quest quest){

    new entity, linkedButton;
    if(quest.linkedEntity.type == Prop_Dynamic) if((entity = CreateEntityByName("prop_dynamic")) == -1) return;
    if(quest.linkedEntity.type == Prop_Dynamic_Override) if((entity = CreateEntityByName("prop_dynamic_override")) == -1) return;
    if((linkedButton = CreateEntityByName("func_button")) == -1) return;

    if(quest.hasSound) PrecacheSound(quest.soundName, true);

    entity = entQuestItemCreate(client, entity, quest);
    linkedButton = linkedButtonQuestItemCreate(linkedButton, entity, quest);

    g_QuestItemList[client][0] = entity;
    g_QuestItemList[client][1] = linkedButton;

    TeleportEntity(entity, quest.linkedEntity.pos, NULL_VECTOR, NULL_VECTOR);
    TeleportEntity(linkedButton, quest.linkedEntity.pos, NULL_VECTOR, NULL_VECTOR);

    //HookSingleEntityOutput(linkedButton, "OnPressed", OnQuestCompletion, false);
	SDKHook(linkedButton, SDKHook_Use, OnQuestCompletionAction);

}

public GenerateActivateQuestItem(int client, Quest quest){
    
    new entity;
	new linkedButton = -1;
    
    if(quest.hasSound) PrecacheSound(quest.soundName, true);

    switch(quest.linkedEntity.type){

        case(Prop_Static): 
        {

            entity = -1;
            if((linkedButton = CreateEntityByName("func_button")) == -1) return;
            linkedButton = linkedButtonQuestItemCreate(linkedButton, entity, quest);

            g_QuestItemList[client][1] = linkedButton;
            TeleportEntity(linkedButton, quest.linkedEntity.pos, NULL_VECTOR, NULL_VECTOR);
        }

        case(Prop_Dynamic): 
        {
            if(quest.linkedEntity.hasHammerid)
            {
                entity = Entity_FindByHammerId(quest.linkedEntity.hammerid);
                if(entity == -1)
                {
                    PrintToServer("Quest #%d, %s Has a bad HAMMERID, Generating a default entity", quest.ID, quest.name);
                    if((entity = CreateEntityByName("prop_dynamic")) == -1) return;
                    entity = entQuestItemCreate(client, entity, quest);
                }
                GetEntPropVector(entity, Prop_Send, "m_vecOrigin", quest.linkedEntity.pos);
            }

            else
            {
                if((entity = CreateEntityByName("prop_dynamic")) == -1) return;
                entity = entQuestItemCreate(client, entity, quest);
                TeleportEntity(entity, quest.linkedEntity.pos, NULL_VECTOR, NULL_VECTOR);
            }

            if((linkedButton = CreateEntityByName("func_button")) == -1) return;
            linkedButton = linkedButtonQuestItemCreate(linkedButton, entity, quest);
            g_QuestItemList[client][1] = linkedButton;
            TeleportEntity(linkedButton, quest.linkedEntity.pos, NULL_VECTOR, NULL_VECTOR);

        }

        // Pour une raison inconnue, Sourcepawn refuse les switch avec plusieurs items pour un même cas,
        // Voici donc du code doublé. Merci Sourcepawn!

        case(Prop_Dynamic_Override):
        {
            if(quest.linkedEntity.hasHammerid)
            {
                entity = Entity_FindByHammerId(quest.linkedEntity.hammerid);
                if(entity == -1)
                {
                    PrintToServer("Quest #%d, %s Has a bad HAMMERID, Generating a default entity", quest.ID, quest.name);
                    if((entity = CreateEntityByName("prop_dynamic_override")) == -1) return;
                    entity = entQuestItemCreate(client, entity, quest);
                }
                GetEntPropVector(entity, Prop_Send, "m_vecOrigin", quest.linkedEntity.pos);
            }

            else
            {
                if((entity = CreateEntityByName("prop_dynamic_override")) == -1) return;
                entity = entQuestItemCreate(client, entity, quest);
                TeleportEntity(entity, quest.linkedEntity.pos, NULL_VECTOR, NULL_VECTOR);
            }

            if((linkedButton = CreateEntityByName("func_button")) == -1) return;
            linkedButton = linkedButtonQuestItemCreate(linkedButton, entity, quest);
            g_QuestItemList[client][1] = linkedButton;
            TeleportEntity(linkedButton, quest.linkedEntity.pos, NULL_VECTOR, NULL_VECTOR);

        }

        case(Func_Button): 
        {

            if(!quest.linkedEntity.hasHammerid) PrintToServer("Quest : #%d : %s Requires a HammerID!", quest.ID, quest.name);
            
            else
            {            
                entity = Entity_FindByHammerId(quest.linkedEntity.hammerid);
                g_QuestItemList[client][1] = entity;
                GetEntPropVector(entity, Prop_Send, "m_vecOrigin", quest.linkedEntity.pos);
            }
        }

        case(Func_Door):
        {
			if(!quest.linkedEntity.hasHammerid) PrintToServer("Quest : #%d : %s Requires a HammerID!", quest.ID, quest.name);
            
            else
            {            
                entity = Entity_FindByHammerId(quest.linkedEntity.hammerid);
                GetEntPropVector(entity, Prop_Send, "m_vecOrigin", quest.linkedEntity.pos);
			    //HookSingleEntityOutput(entity, "OnOpen", OnQuestCompletion, false);
			    //
			    SDKHook(entity, SDKHook_Use, OnQuestCompletionAction);
                g_QuestItemList[client][1] = -1;
        	}
		}

        default: 
        {
            PrintToServer("Error, Quest : %d, %s : Cannot generate such an item type : %d", quest.ID, quest.name, quest.linkedEntity.type);
        }
    }


    g_QuestItemList[client][0] = entity;
    
	//if(linkedButton != -1) HookSingleEntityOutput(g_QuestItemList[client][1], "OnPressed", OnQuestCompletion, false);
	// Fonction qui marche pas ^
	
	if(g_QuestItemList[client][1] != -1) SDKHook(g_QuestItemList[client][1], SDKHook_Use, OnQuestCompletionAction);

}


public GenerateDestroyQuestItem(int client, Quest quest){

    new entity;
    
    if(!quest.linkedEntity.hasHammerid){

        if((entity = CreateEntityByName("func_breakable")) == -1) return;
        entity = entQuestItemCreate(client, entity, quest);
        TeleportEntity(entity, quest.linkedEntity.pos, NULL_VECTOR, NULL_VECTOR);

    }

    else{
        entity = Entity_FindByHammerId(quest.linkedEntity.hammerid);
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", quest.linkedEntity.pos);   
    }

    if(quest.hasSound) PrecacheSound(quest.soundName, true);

    g_QuestItemList[client][0] = entity;
    g_QuestItemList[client][1] = entity;

    HookSingleEntityOutput(entity, "OnBreak", OnQuestCompletionForBreak, false);
	// Fonction pas dérangeante ici
}


// GENERAL FUNCTION, CALLED FROM quests.sp

public GenerateQuestItems(int client, Quest quest){
    if (quest.ID == EMPTYQUEST.ID) return;

    switch(quest.type){

        case(Fetch):{
            GenerateFetchQuestItem(client, quest);
        }

        case(Activate):{
            GenerateActivateQuestItem(client, quest);
        }

        case(Destroy):{
            GenerateDestroyQuestItem(client, quest);
        }

        default:{
            
        }

    }

}


