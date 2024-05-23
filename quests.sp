enum Quest_Type{
    Fetch,
    Activate,
    Destroy
};

enum Object_Type{
	Prop_Static,
	Prop_Dynamic,
	Prop_Dynamic_Override,
	Func_Button,
	Func_Breakable,
	Func_Door
};

enum Reward_Type{
	New_Quest,
	Credits,
	Shop_Item
};

enum struct Reward{
	Reward_Type type;
	int value;		// Représente le nombre de crédits / l'ID de la prochaine quête  / l'ID de l'objet du store
}

enum Effect_Type{
	Fire,
	Smoke,
	Spark
};

enum struct Object{
	Object_Type type;
	float pos[3];
	float rot[3];
	float sizeOverrideMin[3];
	float sizeOverrideMax[3];
	char skin[256];
	bool isActivableButton;
	bool isDamageButton;
	
	bool hasHammerid;
	int hammerid;

	bool hasEffect;
	Effect_Type effect;

	bool destroy;

}


enum struct Quest{
    int ID;
	int side; // 0 for T only, 1 for CT, 2 for Both
    Quest_Type type;
    char name[64];
    char map[128];
    char description[256];
    char solution[256];    // Donne la 'solution' de la quête; ex : "Prendre le pain se trouvant sur le comptoir de la cuisine"

	bool hasSound;
	char soundName[128];

	Object linkedEntity;
	Reward reward;

}


char QUEST_IDENTIFIER = '/';
int g_mapQuestNumber;
int g_TQuestNumber;
int g_CTQuestNumber;
int g_restrictedQuest[128];
int g_restrictedQuestNumber;
char g_DB[] = "bajail";
Quest questList[128];
Quest TSideQuests[128];
Quest CTSideQuests[128];
Quest EMPTYQUEST;
Quest playersQuests[MAXPLAYERS+1];

bool QUEST_LIMIT_PLAYERS = false;

char g_habitueNameList[][32] = {"A que coucou bob", "Moulman", "Netiiqs", "Ziko", "Raphi", "Wiidow", "Nero", "Maestro", 
	"Clem", "JeSuisNéDansUnOeuf", "Carson", "Killians", "Aylo", "WeedForSpeed", "BKR"};
int g_habitueNameNumber = 15;


public Quests_OnPluginStart(){

	RegConsoleCmd("sm_quest", RemindQuest, "Redonne la quête actuelle du joueur");
	RegAdminCmd("sm_givequest", GiveQuest, ADMFLAG_GENERIC, "Donne une nouvelle quête");
	RegAdminCmd("sm_questsolution", SolveQuest, ADMFLAG_GENERIC, "Donne la solution de la quête");

	EMPTYQUEST.ID = -1;
	EMPTYQUEST.type = Fetch;
	EMPTYQUEST.side = 2;
	Format(EMPTYQUEST.name, sizeof(EMPTYQUEST.name), "%s", "Pas de quête");
	Format(EMPTYQUEST.description, sizeof(EMPTYQUEST.description), "%s", "Vous n'avez actuellement pas de quête!");
	Format(EMPTYQUEST.map, sizeof(EMPTYQUEST.map), "%s", "UNIVERSAL");
	Format(EMPTYQUEST.solution, sizeof(EMPTYQUEST.solution), "%s", "Attendez le prochain round pour obtenir une nouvelle quête!");

}

public int FindQuestWithID(int id){
	for(int i = 0; i < g_mapQuestNumber; i++){
		if(questList[i].ID == id) return i;
	}
	return 0;
}


/*
public int GetQuestTeam(int questID){
	for(int i = 0; i < g_CTQuestNumber; i++){
		if(CTSideQuests[i].ID == questID) return 3;
	}
	return 2;
}
*/

public void T_QuestData(Database db, DBResultSet results, const char[] error, int data){


	// Requêtes à la base de données

	if(db == null || results == null)
    {
        LogError("T_QuestData returned error: %s", error);
        return;
    }

	if(!SQL_FetchRow(results)){
		playersQuests[data] = EMPTYQUEST;
		return;
	}

	char questName[256];
	results.FetchString(0, questName, 256);
		
	char bob_the_builder[256];
	char bob_the_mapper[256];
	int builder_beginning;
	bool build = false;

	for(int j = 0; j < 256; j++){

		if(questName[j] == QUEST_IDENTIFIER){
			build = true;
			builder_beginning = j;
			j++;
		}

		if(build) bob_the_builder[j - builder_beginning] = questName[j];
		else bob_the_mapper[j] = questName[j];
	}

	if(StrEqual(bob_the_mapper, current_map)) playersQuests[data] = questList[FindQuestWithID(StringToInt(bob_the_builder))];
	else playersQuests[data] = EMPTYQUEST;
	delete results;
	return;

}


public SetQuestFromDB(int client){

	char query[256];
	char steamid[64];
	decl String:bit[2][64];
	char steamid1[64];
	char steamid2[64];
	
	DBResultSet queryResult;

	if(IsClientConnected(client)){
		GetClientAuthString(client, steamid, sizeof(steamid));
		ExplodeString(steamid, ":", bit, sizeof bit, sizeof bit[], 2);
		Format(steamid1, sizeof(steamid1), "STEAM_0:%s", bit[1]);
		Format(steamid2, sizeof(steamid2), "STEAM_1:%s", bit[1]);
		FormatEx(query, sizeof(query), "SELECT quest FROM jail_players WHERE steam_id = '%s' OR steam_id = '%s'", steamid1, steamid2);
		g_Database.Query(T_QuestData, query, client);
	}
}


public UploadQuestToDB(int client){

	char questBuffer[256];
	char questNumberBuffer[5];
	char query[256];
	char steamid[64];
	decl String:bit[2][64];
	char steamid1[64];
	char steamid2[64];

	Format(questBuffer, sizeof(questBuffer), "%s%c%s", current_map, QUEST_IDENTIFIER, IntToString(playersQuests[client].ID, questNumberBuffer, sizeof(questNumberBuffer)));
	GetClientAuthString(client, steamid, sizeof(steamid));
	ExplodeString(steamid, ":", bit, sizeof bit, sizeof bit[], 2);
	Format(steamid1, sizeof(steamid1), "STEAM_0:%s", bit[1]);
	Format(steamid2, sizeof(steamid2), "STEAM_1:%s", bit[1]);
	Format(query, sizeof(query), "UPDATE jail_players SET quest = '%s' WHERE (steam_id = '%s' OR steam_id = '%s')", questBuffer, steamid1, steamid2);
}



public Quests_OnPlayerConnect(int client){
	if(ValidPlayer(client)) SetQuestFromDB(client);
}

public isRestrictedQuest(int questID){
	for(int i = 0; i < g_restrictedQuestNumber; i++) if(g_restrictedQuest[i] == questID) return true;
	return false;
}

public isCorrectTeamForQuest(int client){
	if(playersQuests[client].side == 2) return true;
	if(GetClientTeam(client) == 2) return (playersQuests[client].side == 0);
	return (playersQuests[client].side == 1);
}

public Quests_OnMapStart(){

	/*
	
	Quand la map charge:
		- On charge les quêtes relative à la map
		- Pour chaque client connecté, on regarde dans la base de données si sa quête précédente était sur la map actuelle
	
	
	*/ 

	BuildQuests();

	for(int i = 1; i < MaxClients+1; i++) SetQuestFromDB(i);
	

}




// -------------------- Attribution des quêtes + commandes usuelles --------------------

public Action RemindQuest(int client, int arg){
	// Plusieurs print pour la lisibilité + Limite de caractère ???
	CPrintToChat(client, "\n▬▬▬ {green}Quête actuelle{default} ▬▬▬");
	CPrintToChat(client, "{yellow}• %s{default}\n", playersQuests[client].name);
	CPrintToChat(client, "{orange}- %s{default}", playersQuests[client].description);
	CPrintToChat(client, "▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬\n");
	//CPrintToChat(client, "Quest ID : %d", playersQuests[client].ID);
	return Plugin_Handled;

}

public int playerCount(){
	int returnVal = 0;
	for(int i = 1; i < MaxClients+1; i++){
		if(ValidPlayer(i)) returnVal++;
	}
	return returnVal;
}


public Quests_OnRoundStart(){

	if(QUEST_LIMIT_PLAYERS && (playerCount() < 5)) return;

	for(int i = 1; i < MaxClients+1; i++){
		if(ValidPlayer(i)){
			if(playersQuests[i].ID <= 0 || StrEqual(playersQuests[i].name, "") || !isCorrectTeamForQuest(i)){

				if(GetClientTeam(i) == 2) 
					while(isRestrictedQuest((playersQuests[i] = TSideQuests[GetRandomInt(0, g_TQuestNumber - 1)]).ID)){}
				else if(GetClientTeam(i) == 3) 
					while(isRestrictedQuest((playersQuests[i] = CTSideQuests[GetRandomInt(0, g_CTQuestNumber - 1)]).ID)){}
				else playersQuests[i] = EMPTYQUEST;
			}
			RemindQuest(i, 0);

			GenerateQuestItems(i, playersQuests[i]);
		}
	}
}

public Action GiveQuest(int client, int arg){

	char argFromCommand[8];
	GetCmdArgString(argFromCommand, sizeof(argFromCommand));
	if(StrEqual(argFromCommand, "")) GiveQuestF(client, 0);
	else GiveQuestF(client, StringToInt(argFromCommand));

	return Plugin_Handled;
}


public GiveQuestF(int client, int arg){


	if(!ValidPlayer(client)) return Plugin_Handled;

	if(arg != 0) playersQuests[client] = questList[FindQuestWithID(arg)];
	else if(arg == 0 && GetClientTeam(client) == 2)
		while(isRestrictedQuest((playersQuests[client] = TSideQuests[GetRandomInt(0, g_TQuestNumber - 1)]).ID)){}
	else if(arg == 0 && GetClientTeam(client) == 3) 
		while(isRestrictedQuest((playersQuests[client] = CTSideQuests[GetRandomInt(0, g_CTQuestNumber - 1)]).ID)){}
	else playersQuests[client] = EMPTYQUEST; // Le client n'est pas dans une team connue

	UploadQuestToDB(client);
	
	RemindQuest(client, 0);

	//GenerateQuestItems(client, playersQuests[client]);
}

public Action SolveQuest(int client, int arg){
	CPrintToChat(client, "\n{blue}%s{default}\n", playersQuests[client].solution);
	return Plugin_Handled;
}


// ---------------------  Parsage du .ini avec un KV  --------------------------

public int BrowseQuestSubSection(KeyValues kv, int currentIndex, Quest_Type currentType){
	
	do{
		Quest builder;
		builder.map = current_map;
		builder.type = currentType;

		Object builder_object;
		Reward builder_reward;

		// BUILDER

		char buffer[256];
		char side[8];
		KvGetSectionName(kv, buffer, sizeof(buffer));
		builder.ID = StringToInt(buffer);
		KvGetString(kv, "side", side, sizeof(side));

		if(StrEqual(side, "T")) builder.side = 0;
		else if(StrEqual(side, "CT")) builder.side = 1;
		else builder.side = 2;

		KvGetString(kv, "name", builder.name, sizeof(builder.name), "New Quest");
		KvGetString(kv, "description", builder.description, sizeof(builder.description), "Complete this quest, somehow...");
		KvGetString(kv, "solution", builder.solution, sizeof(builder.solution), "I'd help if I could...");

		int randomIndex1 = GetRandomInt(0, g_habitueNameNumber - 1);
		int randomIndex2;
		while((randomIndex2 = GetRandomInt(0, g_habitueNameNumber - 1)) == randomIndex1){}

		int temp = ReplaceString(builder.description, sizeof(builder.description), "<X>", g_habitueNameList[randomIndex1]);
		temp = ReplaceString(builder.description, sizeof(builder.description), "<Y>", g_habitueNameList[randomIndex2]);

		// OBJECT

		char bufferObjectType[256];
		char bufferObjectInfo[32];
		char bufferObjectSkin[256];

		float ObjPos[3];
		float ObjRot[3];
		builder_object.pos = ObjPos;
		builder_object.rot = ObjRot;

		KvGetString(kv, "entity", bufferObjectType, sizeof(bufferObjectType), "prop_dynamic");
		if(StrEqual(bufferObjectType, "prop_dynamic")) builder_object.type = Prop_Dynamic;
		else if (StrEqual(bufferObjectType, "prop_static")) builder_object.type = Prop_Static;
		else if (StrEqual(bufferObjectType, "prop_dynamic_override")) builder_object.type = Prop_Dynamic_Override;
		else if (StrEqual(bufferObjectType, "func_button")) builder_object.type = Func_Button;
		else if  (StrEqual(bufferObjectType, "func_breakable")) builder_object.type = Func_Breakable;
		else builder_object.type = Func_Door;

		KvGetString(kv, "x", bufferObjectInfo, sizeof(bufferObjectInfo), "0");
		builder_object.pos[0] = StringToFloat(bufferObjectInfo);
		KvGetString(kv, "y", bufferObjectInfo, sizeof(bufferObjectInfo), "0");
		builder_object.pos[1] = StringToFloat(bufferObjectInfo);
		KvGetString(kv, "z", bufferObjectInfo, sizeof(bufferObjectInfo), "0");
		builder_object.pos[2] = StringToFloat(bufferObjectInfo);

		KvGetString(kv, "pitch", bufferObjectInfo, sizeof(bufferObjectInfo), "0");
		builder_object.rot[0] = StringToFloat(bufferObjectInfo);
		KvGetString(kv, "yaw", bufferObjectInfo, sizeof(bufferObjectInfo), "0");
		builder_object.rot[1] = StringToFloat(bufferObjectInfo);
		KvGetString(kv, "roll", bufferObjectInfo, sizeof(bufferObjectInfo), "0");
		builder_object.rot[2] = StringToFloat(bufferObjectInfo);

		KvGetString(kv, "xmin", bufferObjectInfo, sizeof(bufferObjectInfo), "0");
		builder_object.sizeOverrideMin[0] = StringToFloat(bufferObjectInfo);
		KvGetString(kv, "ymin", bufferObjectInfo, sizeof(bufferObjectInfo), "0");
		builder_object.sizeOverrideMin[1] = StringToFloat(bufferObjectInfo);
		KvGetString(kv, "zmin", bufferObjectInfo, sizeof(bufferObjectInfo), "0");
		builder_object.sizeOverrideMin[2] = StringToFloat(bufferObjectInfo);

		KvGetString(kv, "xmax", bufferObjectInfo, sizeof(bufferObjectInfo), "0");
		builder_object.sizeOverrideMax[0] = StringToFloat(bufferObjectInfo);
		KvGetString(kv, "ymax", bufferObjectInfo, sizeof(bufferObjectInfo), "0");
		builder_object.sizeOverrideMax[1] = StringToFloat(bufferObjectInfo);
		KvGetString(kv, "zmax", bufferObjectInfo, sizeof(bufferObjectInfo), "0");
		builder_object.sizeOverrideMax[2] = StringToFloat(bufferObjectInfo);

		KvGetString(kv, "skin", builder_object.skin, sizeof(builder_object.skin), "models/weapons/v_knife_css_inspect.mdl");


		// HAMMERID

		char bufferHammerid[128];
		KvGetString(kv, "hammerid", bufferHammerid, sizeof(bufferHammerid), "NONE");
		if(StrEqual(bufferHammerid, "NONE")) builder_object.hasHammerid = false;
		else{
			builder_object.hasHammerid = true;
			builder_object.hammerid = StringToInt(bufferHammerid);
		}


		// DESTROY ON COMPLETION
		char bufferDestroy[128];
		KvGetString(kv, "hammerid", bufferDestroy, sizeof(bufferDestroy), "true");
		if(StrEqual(bufferDestroy, "true")) builder_object.destroy = true;
		else builder_object.destroy = false;


		// EFFECTS

		char bufferEffect[128];
		KvGetString(kv, "effect", bufferEffect, sizeof(bufferEffect), "NONE");
		if(StrEqual(bufferEffect, "NONE")) builder_object.hasEffect = false;
		else{
			builder_object.hasEffect = true;
			if(StrEqual(bufferEffect, "fire")) builder_object.effect = Fire;
			if(StrEqual(bufferEffect, "smoke")) builder_object.effect = Smoke;
			if(StrEqual(bufferEffect, "spark")) builder_object.effect = Spark;
		}
		
		builder.linkedEntity = builder_object;

		
		// SOUND

		char bufferSound[128];
		KvGetString(kv, "sound", bufferSound, sizeof(bufferSound), "NONE");
		if(StrEqual(bufferSound, "NONE")) builder.hasSound = false;
		else{
			builder.hasSound = true;
			builder.soundName = bufferSound;
		}


		//  REWARD

		char bufferRewardValue[32];
		

		KvGetString(kv, "reward", bufferRewardValue, sizeof(bufferRewardValue), "C/0");

		switch(bufferRewardValue[0]){
			case 'C':
			{
				Format(bufferRewardValue, 30, "%s", bufferRewardValue[2]);
				builder_reward.type = Credits;
			}

			case 'Q':
			{
				Format(bufferRewardValue, 30, "%s", bufferRewardValue[2]);
				builder_reward.type = New_Quest;
				g_restrictedQuest[g_restrictedQuestNumber++] = StringToInt(bufferRewardValue);
			}

			case 'I':
			{
				Format(bufferRewardValue, 30, "%s", bufferRewardValue[2]);
				builder_reward.type = Shop_Item;
			}

			default:
			{
				Format(bufferRewardValue, 30, "%s", bufferRewardValue[2]);
				builder_reward.type = Credits;
			}
		}

		builder_reward.value = StringToInt(bufferRewardValue);
		builder.reward = builder_reward;
		
		questList[currentIndex++] = builder;
		g_mapQuestNumber++;

	} while(kv.GotoNextKey());
	
	kv.Rewind();
	return currentIndex; // Il faudrait passer un pointeur vers questInd mais sourcepawn...
}


public BuildQuests(){

	int questInd = 1;
	g_mapQuestNumber = 1;
	g_TQuestNumber = 1;
	g_CTQuestNumber = 1;
	g_restrictedQuestNumber = 0;

	questList[0] = EMPTYQUEST;
	TSideQuests[0] = EMPTYQUEST;
	CTSideQuests[0] = EMPTYQUEST;

	char questFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, questFile, sizeof(questFile), "data/bajail/quests/%s.ini", current_map);

	KeyValues KvTree = new KeyValues("Quests");

	if (!KvTree.ImportFromFile(questFile)) {
		PrintToServer("Error, Couldn't load data/bajail/quests/%s.ini", current_map);
		return;
	}

	if(KvTree.JumpToKey("Fetch") && KvGotoFirstSubKey(KvTree)) questInd = BrowseQuestSubSection(KvTree, questInd, Fetch);


	if(KvTree.JumpToKey("Activate") && KvGotoFirstSubKey(KvTree)) questInd = BrowseQuestSubSection(KvTree, questInd, Activate);


	if(KvTree.JumpToKey("Destroy") && KvGotoFirstSubKey(KvTree)) questInd = BrowseQuestSubSection(KvTree, questInd, Destroy);

	delete KvTree;

	for(int i = 0; i < g_mapQuestNumber; i++){
		if(questList[i].side == 0) TSideQuests[g_TQuestNumber++] = questList[i];

		else if(questList[i].side == 1) CTSideQuests[g_CTQuestNumber++] = questList[i];

		else{
			CTSideQuests[g_CTQuestNumber++] = questList[i];
			TSideQuests[g_TQuestNumber++] = questList[i];
		}

	}

}




