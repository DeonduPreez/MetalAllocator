#include <sourcemod>
#include <cstrike>
#include <clientprefs>
#include "include/retakes.inc"
#include "retakes/generic.sp"

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.0.1"

#define MENU_TIME_LENGTH 15

char g_CTRifleChoice[MAXPLAYERS+1][WEAPON_STRING_LENGTH];
char g_CTPistolChoice[MAXPLAYERS+1][WEAPON_STRING_LENGTH];
char g_CTPistolOnlyChoice[MAXPLAYERS+1][WEAPON_STRING_LENGTH];
char g_TRifleChoice[MAXPLAYERS+1][WEAPON_STRING_LENGTH];
char g_TPistolChoice[MAXPLAYERS+1][WEAPON_STRING_LENGTH];
char g_TPistolOnlyChoice[MAXPLAYERS+1][WEAPON_STRING_LENGTH];
bool g_AwpChoice[MAXPLAYERS+1];
Handle g_hCTRifleChoiceCookie;
Handle g_hTRifleChoiceCookie;
Handle g_hCTPistolChoiceCookie;
Handle g_hTPistolChoiceCookie;
Handle g_hCTPistolOnlyChoiceCookie;
Handle g_hTPistolOnlyChoiceCookie;
Handle g_hAwpChoiceCookie;

int RoundCount = -3;

public Plugin myinfo = {
    name = "CS:GO Retakes: metal weapon allocator",
    author = "metalinjection",
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
    g_hAwpChoiceCookie = RegClientCookie("retakes_awpchoice", "", CookieAccess_Private);
    
    HookEvent("round_start", Event_RoundStart);
}

public void OnMapStart()
{
    PrintToServer("Map started");
    RoundCount = -3;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    RoundCount++;
    PrintToChatAll("Round Started: %d", RoundCount);
    return Plugin_Continue;
} 

public void OnClientConnected(int client) {
    g_CTRifleChoice[client] = "m4a1";
    g_TRifleChoice[client] = "ak47";
    g_AwpChoice[client] = false;
}

public void Retakes_OnGunsCommand(int client) {
    GiveWeaponsMenu(client);
}

public void Retakes_OnWeaponsAllocated(ArrayList tPlayers, ArrayList ctPlayers, Bombsite bombsite) {
    WeaponAllocator(tPlayers, ctPlayers, bombsite);
}

/**
 * Updates client weapon settings according to their cookies.
 */
public void OnClientCookiesCached(int client) {
    PrintToServer("OnClientCookiesCached: %d", client);
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
    bool awpchoice = GetCookieBool(client, g_hAwpChoiceCookie);
    
    
    g_CTRifleChoice[client] = StrEqual(ctrifle, "") ? "m4a1" : ctrifle;
    g_CTPistolChoice[client] = StrEqual(ctpistol, "") ? "usp_silencer" : ctpistol;
    g_CTPistolOnlyChoice[client] = StrEqual(ctpistolonly, "") ? "usp_silencer" : ctpistolonly;
    g_TRifleChoice[client] = StrEqual(trifle, "") ? "ak47" : trifle;
    g_TPistolChoice[client] = StrEqual(tpistol, "") ? "glock" : tpistol;
    g_TPistolOnlyChoice[client] = StrEqual(tpistolonly, "") ? "glock" : tpistolonly;
    g_AwpChoice[client] = awpchoice;
}

static void SetNades(char nades[NADE_STRING_LENGTH]) {
    int rand = GetRandomInt(0, 3);
    switch(rand) {
        case 0: nades = "";
        case 1: nades = "s";
        case 2: nades = "f";
        case 3: nades = "h";
    }
}

public void WeaponAllocator(ArrayList tPlayers, ArrayList ctPlayers, Bombsite bombsite) {
    int tCount = tPlayers.Length;
    int ctCount = ctPlayers.Length;

    bool isPistolRound = RoundCount < 5;
    PrintToChatAll("isPistolRound: %b", isPistolRound);

    char primary[WEAPON_STRING_LENGTH] = "weapon_";
    char secondary[WEAPON_STRING_LENGTH] = "weapon_";
    char nades[NADE_STRING_LENGTH];
    int health = 100;
    int kevlar = 100;
    bool helmet = !isPistolRound;
    bool kit = true;

    bool giveTAwp = true;
    bool giveCTAwp = true;

    // T setup
    for (int i = 0; i < tCount; i++) {
    	primary = "weapon_";
    	secondary = "weapon_";

        int client = tPlayers.Get(i);

        if (isPistolRound)
        {
        	primary = "";
        }
        else if (giveTAwp && g_AwpChoice[client]) {
            StrCat(primary, sizeof(primary), "awp");
            giveTAwp = false;
        } else {
        	StrCat(primary, sizeof(primary), g_TRifleChoice[client]);
        }
        
    	StrCat(secondary, sizeof(secondary), g_TPistolChoice[client]);

        health = 100;
        kit = false;
        SetNades(nades);
        kevlar = (!isPistolRound || (StrEqual(nades, ""))) ? 100 : 0;

        Retakes_SetPlayerInfo(client, primary, secondary, nades, health, kevlar, helmet, kit);
    }

    // CT setup
    for (int i = 0; i < ctCount; i++) {
    	primary = "weapon_";
    	secondary = "weapon_";

        int client = ctPlayers.Get(i);

        if (isPistolRound)
        {
        	primary = "";
        }
        else if (giveCTAwp && g_AwpChoice[client]) {
            StrCat(primary, sizeof(primary), "awp");
            giveCTAwp = false;
        } else {
        	StrCat(primary, sizeof(primary), g_CTRifleChoice[client]);
        }

        StrCat(secondary, sizeof(secondary), g_CTPistolChoice[client]);
        
        health = 100;
        SetNades(nades);
        kevlar = (!isPistolRound || (StrEqual(nades, ""))) ? 100 : 0;
        kit = !isPistolRound || (StrEqual(nades, "")); // On pistol round, will only have a kit if they have no nades

        Retakes_SetPlayerInfo(client, primary, secondary, nades, health, kevlar, helmet, kit);
    }
}

public void GiveWeaponsMenu(int client) {
	int clientTeam = GetClientTeam(client);
	
	if (clientTeam == CS_TEAM_CT)
	{
		CTRifleMenu(client);
	}
	if (clientTeam == CS_TEAM_T)
	{
		TRifleMenu(client);
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
        CTPistolMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void CTPistolMenu(int client) {
    Menu menu = new Menu(MenuHandler_CTPistol);
    menu.SetTitle("Select a CT pistol:");
    menu.AddItem("usp_silencer", "USP-S");
    menu.AddItem("hkp2000", "P2000");
    menu.AddItem("fiveseven", "Five-Seven");
    menu.AddItem("p250", "P250");
    menu.AddItem("deagle", "Deagle");
    menu.AddItem("revolver", "Revolvo");
    
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_CTPistol(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char choice[WEAPON_STRING_LENGTH];
        menu.GetItem(param2, choice, sizeof(choice));
        g_CTPistolChoice[client] = choice;
        SetClientCookie(client, g_hCTPistolChoiceCookie, choice);
        GiveAwpMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void TRifleMenu(int client) {
    Menu menu = new Menu(MenuHandler_TRifle);
    menu.SetTitle("Select a T rifle:");
    menu.AddItem("ak47", "AK-47");
    menu.AddItem("sg556", "SG-556");
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
        TPistolMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void TPistolMenu(int client) {
    Menu menu = new Menu(MenuHandler_TPistol);
    menu.SetTitle("Select a CT pistol:");
    menu.AddItem("glock", "Glock-18");
    menu.AddItem("tec9", "Tec-9");
    menu.AddItem("p250", "P250");
    menu.AddItem("deagle", "Deagle");
    menu.AddItem("revolver", "Revolvo");
    
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_TPistol(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char choice[WEAPON_STRING_LENGTH];
        menu.GetItem(param2, choice, sizeof(choice));
        g_TPistolChoice[client] = choice;
        SetClientCookie(client, g_hTPistolChoiceCookie, choice);
        GiveAwpMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void GiveAwpMenu(int client) {
    Menu menu = new Menu(MenuHandler_AWP);
    menu.SetTitle("Allow yourself to receive AWPs?");
    AddMenuBool(menu, true, "Yes");
    AddMenuBool(menu, false, "No");
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_AWP(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        bool allowAwps = GetMenuBool(menu, param2);
        g_AwpChoice[client] = allowAwps;
        SetCookieBool(client, g_hAwpChoiceCookie, allowAwps);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}
