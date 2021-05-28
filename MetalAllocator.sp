#include <sourcemod>
#include <cstrike>
#include <clientprefs>
#include "include/retakes.inc"
#include "retakes/generic.sp"

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"

#define MENU_TIME_LENGTH 15

char g_CTRifleChoice[MAXPLAYERS+1][WEAPON_STRING_LENGTH];
char g_CTPistolChoice[MAXPLAYERS+1][WEAPON_STRING_LENGTH];
char g_CTPistolOnlyChoice[MAXPLAYERS+1][WEAPON_STRING_LENGTH];
char g_TRifleChoice[MAXPLAYERS+1][WEAPON_STRING_LENGTH];
char g_TPistolChoice[MAXPLAYERS+1][WEAPON_STRING_LENGTH];
char g_TPistolOnlyChoice[MAXPLAYERS+1][WEAPON_STRING_LENGTH];
bool g_CTAwpChoice[MAXPLAYERS+1];
bool g_TAwpChoice[MAXPLAYERS+1];
Handle g_hCTRifleChoiceCookie;
Handle g_hTRifleChoiceCookie;
Handle g_hCTPistolChoiceCookie;
Handle g_hTPistolChoiceCookie;
Handle g_hCTPistolOnlyChoiceCookie;
Handle g_hTPistolOnlyChoiceCookie;
Handle g_hCTAwpChoiceCookie;
Handle g_hTAwpChoiceCookie;

int RoundCount = 0;
int EnemyWeaponWeight = 10;

ConVar g_cvMAEnemyWeaponWeight;

public Plugin myinfo = {
    name = "CS:GO Retakes: metal weapon allocator",
    author = "Metal Injection",
    description = "Defines a weapon allocation policy and lets players set weapon preferences",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-retakes"
};

public void OnPluginStart() {
    g_hCTRifleChoiceCookie = RegClientCookie("retakes_ctriflechoice", "CT Rifle Choice", CookieAccess_Private);
    g_hTRifleChoiceCookie = RegClientCookie("retakes_triflechoice", "T Rifle Choice", CookieAccess_Private);
    g_hCTPistolChoiceCookie = RegClientCookie("retakes_ctpistolchoice", "CT Pistol Choice", CookieAccess_Private);
    g_hTPistolChoiceCookie = RegClientCookie("retakes_tpistolchoice", "T Pistol Choice", CookieAccess_Private);
    g_hCTPistolOnlyChoiceCookie = RegClientCookie("retakes_ctpistolonlychoice", "CT Pistol Only Choice", CookieAccess_Private);
    g_hTPistolOnlyChoiceCookie = RegClientCookie("retakes_tpistolonlychoice", "T Pistol Only Choice", CookieAccess_Private);
    g_hCTAwpChoiceCookie = RegClientCookie("retakes_ctawpchoice", "", CookieAccess_Private);
    g_hTAwpChoiceCookie = RegClientCookie("retakes_tawpchoice", "", CookieAccess_Private);
    g_cvMAEnemyWeaponWeight = CreateConVar("ma_enemyweaponweight", "10", "Sets the weight of the chance to receive an enemy team weapon", FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_ARCHIVE|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_SPONLY);
    g_cvMAEnemyWeaponWeight.AddChangeHook(EnemyWeaponWeightChange);
    EnemyWeaponWeight = GetConVarInt(g_cvMAEnemyWeaponWeight);
}

public int EnemyWeaponWeightChange(Handle cvar, const char[] oldValue, const char[] newValue)
{
	EnemyWeaponWeight = StringToInt(newValue);
}

public void OnMapStart()
{
    RoundCount = 0;
}

public void Retakes_OnGunsCommand(int client) {
    ShowWeaponsMenu(client);
}

public void Retakes_OnWeaponsAllocated(ArrayList tPlayers, ArrayList ctPlayers, Bombsite bombsite) {
    WeaponAllocator(tPlayers, ctPlayers, bombsite);
    RoundCount++;
}

/**
 * Updates client weapon settings according to their cookies.
 */
public void OnClientCookiesCached(int client) {
    if (IsFakeClient(client))
        return;
    char ctrifle[WEAPON_STRING_LENGTH];
    char ctpistol[WEAPON_STRING_LENGTH];
    char ctpistolonly[WEAPON_STRING_LENGTH];
    char trifle[WEAPON_STRING_LENGTH];
    char tpistol[WEAPON_STRING_LENGTH];
    char tpistolonly[WEAPON_STRING_LENGTH];
    GetClientCookie(client, g_hCTRifleChoiceCookie, ctrifle, sizeof(ctrifle));
    GetClientCookie(client, g_hCTPistolChoiceCookie, ctpistol, sizeof(ctpistol));
    GetClientCookie(client, g_hCTPistolOnlyChoiceCookie, ctpistolonly, sizeof(ctpistolonly));
    GetClientCookie(client, g_hTRifleChoiceCookie, trifle, sizeof(trifle));
    GetClientCookie(client, g_hTPistolChoiceCookie, tpistol, sizeof(tpistol));
    GetClientCookie(client, g_hTPistolOnlyChoiceCookie, tpistolonly, sizeof(tpistolonly));
    bool ctAwpchoice = GetCookieBool(client, g_hCTAwpChoiceCookie);
    bool tAwpchoice = GetCookieBool(client, g_hTAwpChoiceCookie);

    g_CTRifleChoice[client] = IsValidWeapon(ctrifle) ? ctrifle : "m4a1";
    g_CTPistolChoice[client] = IsValidWeapon(ctpistol) ? ctpistol : "usp_silencer";
    g_CTPistolOnlyChoice[client] = IsValidWeapon(ctpistolonly) ? ctpistolonly : g_CTPistolChoice[client];
    g_TRifleChoice[client] = IsValidWeapon(trifle) ? trifle : "ak47";
    g_TPistolChoice[client] = IsValidWeapon(tpistol) ? tpistol : "glock";
    g_TPistolOnlyChoice[client] = IsValidWeapon(tpistolonly) ? tpistolonly : g_TPistolChoice[client];
    g_CTAwpChoice[client] = ctAwpchoice;
    g_TAwpChoice[client] = tAwpchoice;
}

static bool IsValidWeapon(char weapon[WEAPON_STRING_LENGTH])
{
	char weaponDisplay[255];
	AppendWeaponDisplay(weaponDisplay, sizeof(weaponDisplay), weapon);
	return !StrEqual(weaponDisplay, "");
}

static bool SetNadesGetKit(char nades[NADE_STRING_LENGTH], int team, bool isPistolRound, bool ctHasKit) {
    bool hasKit = false;
    int rand = GetRandomInt(0, 7);
    switch(rand) {
        case 0: {
        	nades = "";
        	hasKit = true;
        }
        case 1: {
        	nades = "s";
        	hasKit = true;
        }
        case 2: {
        	nades = "f";
        	hasKit = true;
    	}
        case 3: {
        	nades = "h";
        	hasKit = true;
    	}
        case 4: {
            nades = (team == CS_TEAM_T) ? "m" : "i";
        }
        // Combo nades
        case 5: {
        	nades = "sf";
        }
        case 6: {
        	nades = "sh";
    	}
        case 7: {
        	nades = (team == CS_TEAM_T) ? "mf" : "if";
        }
    }

    hasKit = hasKit || !isPistolRound;

    return !ctHasKit && hasKit;
}

static bool GiveEnemyTeamWeapon()
{
	return GetRandomInt(0, 100) < EnemyWeaponWeight;
}

public void WeaponAllocator(ArrayList tPlayers, ArrayList ctPlayers, Bombsite bombsite) {
    int tCount = tPlayers.Length;
    int ctCount = ctPlayers.Length;

    bool isPistolRound = RoundCount < 5;

    char weaponConstText[7] = "weapon_";

    char primary[WEAPON_STRING_LENGTH];
    char secondary[WEAPON_STRING_LENGTH];
    strcopy(primary, sizeof(primary), weaponConstText);
    strcopy(secondary, sizeof(secondary), weaponConstText);
    char nades[NADE_STRING_LENGTH];
    int health = 100;
    int kevlar = 100;
    bool helmet = !isPistolRound;
    bool kit = true;

    bool giveTAwp = true;
    bool giveCTAwp = true;
    int teammatesWithNades = 0;

    // T setup
    for (int i = 0; i < tCount; i++) {
    	primary = weaponConstText;
    	secondary = weaponConstText;

        int client = tPlayers.Get(i);

        if (isPistolRound)
        {
        	primary = "";
        	StrCat(secondary, sizeof(secondary), g_TPistolOnlyChoice[client]);
        }
        else if (giveTAwp && g_TAwpChoice[client]) {
            StrCat(primary, sizeof(primary), "awp");
            giveTAwp = false;
            StrCat(secondary, sizeof(secondary), g_TPistolChoice[client]);
        } else {
        	if (GiveEnemyTeamWeapon())
        	{
        		StrCat(primary, sizeof(primary), g_CTRifleChoice[client]);
        		char primaryDisplayString[255] = "";
        		AppendWeaponDisplay(primaryDisplayString, sizeof(primaryDisplayString), g_CTRifleChoice[client]);
        		PrintToChat(client, "You received a %s to simulate a weapon pickup on the previous round", primaryDisplayString);
        	}
        	else
        	{
        		StrCat(primary, sizeof(primary), g_TRifleChoice[client]);
        	}
        	StrCat(secondary, sizeof(secondary), g_TPistolChoice[client]);
        }
        
        if (StrEqual(secondary, weaponConstText))
        {
        	StrCat(secondary, sizeof(secondary), g_CTPistolChoice[client]);
        }

        health = 100;
        kit = false;
        if (!isPistolRound || teammatesWithNades <= 2)
        {
        	SetNadesGetKit(nades, CS_TEAM_T, isPistolRound, false);
        	teammatesWithNades = teammatesWithNades + (StrEqual(nades, "") ? 0 : 1);
        }
        kevlar = !isPistolRound ? 100 : isPistolRound && StrEqual(secondary, "weapon_glock") ? 100 : 0;
        if (isPistolRound && kevlar > 0)
        {
        	kevlar = (!isPistolRound || (StrEqual(nades, ""))) ? 100 : 0;
        }

        Retakes_SetPlayerInfo(client, primary, secondary, nades, health, kevlar, helmet, kit);
    }
    
    teammatesWithNades = 0;
    bool ctHasKit = false;
    // CT setup
    for (int i = 0; i < ctCount; i++) {
    	primary = weaponConstText;
    	secondary = weaponConstText;

        int client = ctPlayers.Get(i);

        if (isPistolRound)
        {
        	primary = "";
        	StrCat(secondary, sizeof(secondary), g_CTPistolOnlyChoice[client]);
        }
        else if (giveCTAwp && g_CTAwpChoice[client]) {
            StrCat(primary, sizeof(primary), "awp");
            giveCTAwp = false;
        } else {
        	if (GiveEnemyTeamWeapon())
        	{
        		StrCat(primary, sizeof(primary), g_TRifleChoice[client]);
        		char primaryDisplayString[255] = "";
        		AppendWeaponDisplay(primaryDisplayString, sizeof(primaryDisplayString), g_TRifleChoice[client]);
        		PrintToChat(client, "You received the %s to simulate a weapon pickup on the previous round", primaryDisplayString);
        	}
        	else
        	{
        		StrCat(primary, sizeof(primary), g_CTRifleChoice[client]);
        	}
        }
        
        if (StrEqual(secondary, weaponConstText))
        {
        	StrCat(secondary, sizeof(secondary), g_CTPistolChoice[client]);
        }
        
        health = 100;
        if (!isPistolRound || teammatesWithNades <= 2)
        {
        	kit = SetNadesGetKit(nades, CS_TEAM_CT, isPistolRound, ctHasKit); // On pistol round, will only have a kit if they have no nades
        	teammatesWithNades = teammatesWithNades + (StrEqual(nades, "") ? 0 : 1);
        }

        if (isPistolRound && kit)
        {
        	ctHasKit = true;
        }

        char clientName[255];
        GetClientName(client, clientName, sizeof(clientName));
        char hasKit[255];
        Format(clientName, sizeof(clientName), "hasKit: %b", kit);
        StrCat(clientName, sizeof(clientName), hasKit);

        kevlar = !isPistolRound ? 100 : isPistolRound && (StrEqual(secondary, "weapon_hkp2000") || StrEqual(secondary, "weapon_usp_silencer")) ? 100 : 0;
        if (isPistolRound && kevlar > 0)
        {
            kevlar = !isPistolRound || (isPistolRound && !kit && (StrEqual(nades, ""))) ? 100 : 0;
        }

        Retakes_SetPlayerInfo(client, primary, secondary, nades, health, kevlar, helmet, kit);
    }
}

void AppendWeaponDisplay(char[] buffer, int bufferSize, char[] weapon)
{
    // General Weapons
	if (StrEqual(weapon, "ssg08"))
	{
		StrCat(buffer, bufferSize, "SSG 08");
	}
	else if (StrEqual(weapon, "p250"))
	{
		StrCat(buffer, bufferSize, "P250");
	}
	else if (StrEqual(weapon, "deagle"))
	{
		StrCat(buffer, bufferSize, "Deagle");
	}
	else if (StrEqual(weapon, "revolver"))
	{
		StrCat(buffer, bufferSize, "Revolver");
	}
	else if (StrEqual(weapon, "cz75a"))
	{
		StrCat(buffer, bufferSize, "CZ75-Auto");
	}
	// CT Exclusive Weapons
	else if (StrEqual(weapon, "m4a1"))
	{
		StrCat(buffer, bufferSize, "M4A4");
	}
	else if (StrEqual(weapon, "m4a1_silencer"))
	{
		StrCat(buffer, bufferSize, "M4A1-S");
	}
	else if (StrEqual(weapon, "aug"))
	{
		StrCat(buffer, bufferSize, "AUG");
	}
	else if (StrEqual(weapon, "famas"))
	{
		StrCat(buffer, bufferSize, "Famas");
	}
	else if (StrEqual(weapon, "usp_silencer"))
	{
		StrCat(buffer, bufferSize, "USP-S");
	}
	else if (StrEqual(weapon, "hkp2000"))
	{
		StrCat(buffer, bufferSize, "P2000");
	}
	else if (StrEqual(weapon, "fiveseven"))
	{
		StrCat(buffer, bufferSize, "Five-Seven");
	}
	// T Exclusive Weapons
	else if (StrEqual(weapon, "ak47"))
	{
		StrCat(buffer, bufferSize, "AK-47");
	}
	else if (StrEqual(weapon, "sg556"))
	{
		StrCat(buffer, bufferSize, "SG-553");
	}
	else if (StrEqual(weapon, "galilar"))
	{
		StrCat(buffer, bufferSize, "Galil AR");
	}
	else if (StrEqual(weapon, "glock"))
	{
		StrCat(buffer, bufferSize, "Glock-18");
	}
	else if (StrEqual(weapon, "tec9"))
	{
		StrCat(buffer, bufferSize, "Tec-9");
	}
}

public void ShowWeaponsMenu(int client) {
    Menu menu = new Menu(MenuHandler_LoadoutSelection);
    menu.SetTitle("Select a loadout to edit:");
    menu.AddItem("ctmenu", "CT");
    menu.AddItem("tmenu", "T");
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_LoadoutSelection(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
        int client = param1;
        char choice[255];
        menu.GetItem(param2, choice, sizeof(choice));
        if (StrEqual(choice, "ctmenu"))
        {
        	CTLoadoutMenu(client);
        }
        else
        {
        	TLoadoutMenu(client);
        }
	} else if (action == MenuAction_End) {
		delete menu;
	}
}

public void CTLoadoutMenu(int client) {
    char ctRifleString[255] = "CT Rifle: ";
    AppendWeaponDisplay(ctRifleString, sizeof(ctRifleString), g_CTRifleChoice[client]);
    char ctPistolString[255] = "CT Pistol: ";
    AppendWeaponDisplay(ctPistolString, sizeof(ctPistolString), g_CTPistolChoice[client]);
    char ctPistolOnlyString[255] = "CT Pistol Rounds: ";
    AppendWeaponDisplay(ctPistolOnlyString, sizeof(ctPistolOnlyString), g_CTPistolOnlyChoice[client]);
    char ctAwpString[255] = "CT Awp: ";
    StrCat(ctAwpString, sizeof(ctAwpString), g_CTAwpChoice[client] ? "Always" : "Never");
    
    Menu menu = new Menu(MenuHandler_CTLoadout);
    menu.SetTitle("CT Loadout:");
    menu.AddItem("ctrifle", ctRifleString);
    menu.AddItem("ctpistol", ctPistolString);
    menu.AddItem("ctawp", ctAwpString);
    menu.AddItem("ctpistolrounds", ctPistolOnlyString);
    menu.AddItem("back", "Back");
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_CTLoadout(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
	    int client = param1;
	    char choice[WEAPON_STRING_LENGTH];
	    menu.GetItem(param2, choice, sizeof(choice));
	    
	    if (StrEqual(choice, "back"))
	    {
	    	ShowWeaponsMenu(client);
	    }
	    else if (StrEqual(choice, "ctrifle"))
	    {
	    	CTRifleMenu(client);
	    }
	    else if (StrEqual(choice, "ctpistol"))
	    {
	    	CTPistolMenu(client);
	    }
	    else if (StrEqual(choice, "ctpistolrounds"))
	    {
	    	CTPistolOnlyMenu(client);
	    }
	    else if (StrEqual(choice, "ctawp"))
	    {
	    	//CTAwpMenu(client);
	    	GiveCTAwpMenu(client);
	    }
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void TLoadoutMenu(int client) {
    char tRifleString[255] = "T Rifle: ";
    AppendWeaponDisplay(tRifleString, sizeof(tRifleString), g_TRifleChoice[client]);
    char tPistolString[255] = "T Pistol: ";
    AppendWeaponDisplay(tPistolString, sizeof(tPistolString), g_TPistolChoice[client]);
    char tPistolOnlyString[255] = "T Pistol Rounds: ";
    AppendWeaponDisplay(tPistolOnlyString, sizeof(tPistolOnlyString), g_TPistolOnlyChoice[client]);
    char tAwpString[255] = "T Awp: ";
    StrCat(tAwpString, sizeof(tAwpString), g_TAwpChoice[client] ? "Always" : "Never");
    
    Menu menu = new Menu(MenuHandler_TLoadout);
    menu.SetTitle("T Loadout:");
    menu.AddItem("trifle", tRifleString);
    menu.AddItem("tpistol", tPistolString);
    menu.AddItem("tawp", tAwpString);
    menu.AddItem("tpistolrounds", tPistolOnlyString);
    menu.AddItem("back", "Back");
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_TLoadout(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char choice[255];
        menu.GetItem(param2, choice, sizeof(choice));
        
        if (StrEqual(choice, "back"))
	    {
	    	ShowWeaponsMenu(client);
	    }
        else if (StrEqual(choice, "trifle"))
        {
        	TRifleMenu(client);
        }
        else if (StrEqual(choice, "tpistol"))
        {
        	TPistolMenu(client);
        }
        else if (StrEqual(choice, "tpistolrounds"))
        {
        	TPistolOnlyMenu(client);
        }
        else if (StrEqual(choice, "tawp"))
        {
        	//TAwpMenu(client);
        	GiveTAwpMenu(client);
        }
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void CTRifleMenu(int client) {
    Menu menu = new Menu(MenuHandler_CTRifle);
    menu.SetTitle("Select a CT rifle:");
    menu.AddItem("m4a1", "M4A4");
    menu.AddItem("m4a1_silencer", "M4A1-S");
    menu.AddItem("aug", "AUG");
    menu.AddItem("famas", "Famas");
    menu.AddItem("ssg08", "SSG 08");
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_CTRifle(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char choice[WEAPON_STRING_LENGTH];
        menu.GetItem(param2, choice, sizeof(choice));
        g_CTRifleChoice[client] = choice;
        SetClientCookie(client, g_hCTRifleChoiceCookie, choice);
        CTLoadoutMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void SetCTPistolMenuItems(Menu menu)
{
    menu.AddItem("usp_silencer", "USP-S");
    menu.AddItem("hkp2000", "P2000");
    menu.AddItem("fiveseven", "Five-Seven");
    menu.AddItem("cz75a", "CZ75-Auto");
    menu.AddItem("p250", "P250");
    menu.AddItem("deagle", "Deagle");
    menu.AddItem("revolver", "Revolver");
}

public void CTPistolMenu(int client) {
    Menu menu = new Menu(MenuHandler_CTPistol);
    menu.SetTitle("Select a CT pistol:");
    SetCTPistolMenuItems(menu);
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_CTPistol(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char choice[WEAPON_STRING_LENGTH];
        menu.GetItem(param2, choice, sizeof(choice));
        g_CTPistolChoice[client] = choice;
        SetClientCookie(client, g_hCTPistolChoiceCookie, choice);
        CTLoadoutMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void CTPistolOnlyMenu(int client) {
    Menu menu = new Menu(MenuHandler_CTPistolOnly);
    menu.SetTitle("Select a CT pistol round weapon:");
    SetCTPistolMenuItems(menu);
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_CTPistolOnly(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char choice[WEAPON_STRING_LENGTH];
        menu.GetItem(param2, choice, sizeof(choice));
        g_CTPistolOnlyChoice[client] = choice;
        SetClientCookie(client, g_hCTPistolOnlyChoiceCookie, choice);
        CTLoadoutMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void GiveCTAwpMenu(int client) {
    Menu menu = new Menu(MenuHandler_CTAWP);
    menu.SetTitle("Receive AWPs on CT side?");
    AddMenuBool(menu, true, "Yes");
    AddMenuBool(menu, false, "No");
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_CTAWP(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        bool allowAwps = GetMenuBool(menu, param2);
        g_CTAwpChoice[client] = allowAwps;
        SetCookieBool(client, g_hCTAwpChoiceCookie, allowAwps);
        CTLoadoutMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void TRifleMenu(int client) {
    Menu menu = new Menu(MenuHandler_TRifle);
    menu.SetTitle("Select a T rifle:");
    menu.AddItem("ak47", "AK-47");
    menu.AddItem("sg556", "SG-553");
    menu.AddItem("galilar", "Galil AR");
    menu.AddItem("ssg08", "SSG 08");
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_TRifle(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char choice[WEAPON_STRING_LENGTH];
        menu.GetItem(param2, choice, sizeof(choice));
        g_TRifleChoice[client] = choice;
        SetClientCookie(client, g_hTRifleChoiceCookie, choice);
        TLoadoutMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void SetTPistolMenuItems(Menu menu)
{
    menu.AddItem("glock", "Glock-18");
    menu.AddItem("tec9", "Tec-9");
    menu.AddItem("cz75a", "CZ75-Auto");
    menu.AddItem("p250", "P250");
    menu.AddItem("deagle", "Deagle");
    menu.AddItem("revolver", "Revolver");
}

public void TPistolMenu(int client) {
    Menu menu = new Menu(MenuHandler_TPistol);
    menu.SetTitle("Select a T pistol:");
    SetTPistolMenuItems(menu);
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_TPistol(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char choice[WEAPON_STRING_LENGTH];
        menu.GetItem(param2, choice, sizeof(choice));
        g_TPistolChoice[client] = choice;
        SetClientCookie(client, g_hTPistolChoiceCookie, choice);
        TLoadoutMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void TPistolOnlyMenu(int client) {
    Menu menu = new Menu(MenuHandler_TPistolOnly);
    menu.SetTitle("Select a T pistol round weapon:");
    SetTPistolMenuItems(menu);
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_TPistolOnly(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char choice[WEAPON_STRING_LENGTH];
        menu.GetItem(param2, choice, sizeof(choice));
        g_TPistolOnlyChoice[client] = choice;
        SetClientCookie(client, g_hTPistolOnlyChoiceCookie, choice);
        TLoadoutMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void GiveTAwpMenu(int client) {
    Menu menu = new Menu(MenuHandler_TAWP);
    menu.SetTitle("Receive AWPs on T side?");
    AddMenuBool(menu, true, "Yes");
    AddMenuBool(menu, false, "No");
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_TAWP(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        bool allowAwps = GetMenuBool(menu, param2);
        g_TAwpChoice[client] = allowAwps;
        SetCookieBool(client, g_hTAwpChoiceCookie, allowAwps);
        TLoadoutMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}