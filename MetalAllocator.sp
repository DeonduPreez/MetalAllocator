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
    PrintToServer("Round Started: %d", RoundCount);
    return Plugin_Continue;
} 

public void OnClientConnected(int client) {
    g_CTRifleChoice[client] = "m4a1";
    g_TRifleChoice[client] = "ak47";
    g_AwpChoice[client] = false;
}

public void Retakes_OnGunsCommand(int client) {
    ShowWeaponsMenu(client);
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
    g_CTPistolOnlyChoice[client] = ctpistolonly;
    g_TRifleChoice[client] = StrEqual(trifle, "") ? "ak47" : trifle;
    g_TPistolChoice[client] = StrEqual(tpistol, "") ? "glock" : tpistol;
    g_TPistolOnlyChoice[client] = tpistolonly;
    g_AwpChoice[client] = awpchoice; // TODO : Split into CT and T awp choice
}

static void SetNades(char nades[NADE_STRING_LENGTH], int team) {
    int rand = GetRandomInt(0, 4);
    switch(rand) {
        case 0: nades = "";
        case 1: nades = "s";
        case 2: nades = "f";
        case 3: nades = "h";
        case 4: nades = team == CS_TEAM_T ? "m" : "i";
    }
}

public void WeaponAllocator(ArrayList tPlayers, ArrayList ctPlayers, Bombsite bombsite) {
    int tCount = tPlayers.Length;
    int ctCount = ctPlayers.Length;

    bool isPistolRound = RoundCount < 5;

    char weaponConstText[7] = "weapon_";

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
    	primary = weaponConstText;
    	secondary = weaponConstText;

        int client = tPlayers.Get(i);

        if (isPistolRound)
        {
        	primary = "";
        	StrCat(secondary, sizeof(secondary), g_TPistolOnlyChoice[client]);
        }
        else if (giveTAwp && g_AwpChoice[client]) {
            StrCat(primary, sizeof(primary), "awp");
            giveTAwp = false;
            StrCat(secondary, sizeof(secondary), g_TPistolChoice[client]);
        } else {
        	StrCat(primary, sizeof(primary), g_TRifleChoice[client]);
        	StrCat(secondary, sizeof(secondary), g_TPistolChoice[client]);
        }
        
        if (StrEqual(secondary, weaponConstText))
        {
        	StrCat(secondary, sizeof(secondary), g_CTPistolChoice[client]);
        }

        health = 100;
        kit = false;
        SetNades(nades, CS_TEAM_T);
        kevlar = (!isPistolRound || (StrEqual(nades, ""))) ? 100 : 0;

        Retakes_SetPlayerInfo(client, primary, secondary, nades, health, kevlar, helmet, kit);
    }

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
        else if (giveCTAwp && g_AwpChoice[client]) {
            StrCat(primary, sizeof(primary), "awp");
            giveCTAwp = false;
        } else {
        	StrCat(primary, sizeof(primary), g_CTRifleChoice[client]);
        }
        
        if (StrEqual(secondary, weaponConstText))
        {
        	StrCat(secondary, sizeof(secondary), g_CTPistolChoice[client]);
        }
        
        health = 100;
        SetNades(nades, CS_TEAM_CT);
        kit = !isPistolRound || HasMoneyForDefuseKit(nades); // On pistol round, will only have a kit if they have no nades
        kevlar = (!isPistolRound || (StrEqual(nades, ""))) ? 100 : 0;

        Retakes_SetPlayerInfo(client, primary, secondary, nades, health, kevlar, helmet, kit);
    }
}

bool HasMoneyForDefuseKit(char nades[NADE_STRING_LENGTH])
{
	return !StrEqual(nades, "i");
}

public void ShowWeaponsMenu(int client) {
    char ctRifleString[255] = "CT Rifle: ";
    StrCat(ctRifleString, sizeof(ctRifleString), g_CTRifleChoice[client]);
    char ctPistolString[255] = "CT Pistol: ";
    StrCat(ctPistolString, sizeof(ctPistolString), g_CTPistolChoice[client]);
    char ctPistolOnlyString[255] = "CT Pistol Rounds: ";
    StrCat(ctPistolOnlyString, sizeof(ctPistolOnlyString), g_CTPistolOnlyChoice[client]);
    char ctAwpString[255] = "CT Awp: ";
    StrCat(ctAwpString, sizeof(ctAwpString), g_CTPistolOnlyChoice[client]); // TODO : Split awp into ct and t
    char tRifleString[255] = "T Rifle: ";
    StrCat(tRifleString, sizeof(tRifleString), g_TRifleChoice[client]);
    char tPistolString[255] = "T Pistol: ";
    StrCat(tPistolString, sizeof(tPistolString), g_TPistolChoice[client]);
    char tPistolOnlyString[255] = "T Pistol Rounds: ";
    StrCat(tPistolOnlyString, sizeof(tPistolOnlyString), g_TPistolOnlyChoice[client]);
    char tAwpString[255] = "T Awp: ";
    StrCat(tAwpString, sizeof(tAwpString), g_TPistolOnlyChoice[client]); // TODO : Split awp into ct and t

    Menu menu = new Menu(MenuHandler_LoadoutSelection);
    menu.SetTitle("Select a loadout to edit:");
    menu.AddItem("ctrifle", ctRifleString);
    menu.AddItem("ctpistol", ctPistolString);
    menu.AddItem("ctpistolrounds", ctPistolOnlyString);
    menu.AddItem("ctawp", ctAwpString);
    menu.AddItem("trifle", tRifleString);
    menu.AddItem("tpistol", tPistolString);
    menu.AddItem("tpistolrounds", tPistolOnlyString);
    menu.AddItem("tawp", tAwpString);
    menu.Display(client, MENU_TIME_LENGTH);
}

public int MenuHandler_LoadoutSelection(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char choice[14];
        menu.GetItem(param2, choice, sizeof(choice));
        
        if (StrEqual(choice, "ctrifle"))
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
        	GiveAwpMenu(client);
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
        	GiveAwpMenu(client);
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
        CTPistolMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void SetCTPistolMenuItems(Menu menu)
{
    menu.AddItem("usp_silencer", "USP-S");
    menu.AddItem("hkp2000", "P2000");
    menu.AddItem("fiveseven", "Five-Seven");
    menu.AddItem("p250", "P250");
    menu.AddItem("deagle", "Deagle");
    menu.AddItem("revolver", "Revolvo");
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
        GiveAwpMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void CTPistolOnlyMenu(int client) {
    Menu menu = new Menu(MenuHandler_CTPistolOnly);
    menu.SetTitle("Select a CT pistol for pistol rounds:");
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

public void SetTPistolMenuItems(Menu menu)
{
    menu.AddItem("glock", "Glock-18");
    menu.AddItem("tec9", "Tec-9");
    menu.AddItem("p250", "P250");
    menu.AddItem("deagle", "Deagle");
    menu.AddItem("revolver", "Revolvo");
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
        ShowWeaponsMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void TPistolOnlyMenu(int client) {
    Menu menu = new Menu(MenuHandler_TPistolOnly);
    menu.SetTitle("Select a T pistol for pistol rounds:");
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
        ShowWeaponsMenu(client);
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
