#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <clientprefs>

#define PLUGIN_AUTHOR  "ack"
#define PLUGIN_VERSION "0.7"

public Plugin myinfo = {
	name = "eotl_mri",
	author = PLUGIN_AUTHOR,
	description = "Medic Rage Info (display soldier's rage percent when healing them)",
	version = PLUGIN_VERSION,
	url = ""
};

#define BUFF_TYPE_NONE              -1
#define BUFF_TYPE_BUFF_BANNER       0
#define BUFF_TYPE_BATTALIONS_BACKUP 1
#define BUFF_TYPE_CONCHEROR         2

enum struct PlayerState {
    TFClassType class;
    bool enabled;
    int buffType;
}

PlayerState g_PlayerStates[MAXPLAYERS + 1];
Handle g_hClientCookies;
Handle g_hHudSync;
ConVar g_cvDisplayInterval;
ConVar g_cvXOffset;
ConVar g_cvYOffset;
ConVar g_cvDebug;

char g_sRageWeapons[][] = {
    "Buff Banner",
    "Battalion's Backup",
    "Concheror"
};

public void OnPluginStart() {
    LogMessage("version %s starting", PLUGIN_VERSION);
    HookEvent("player_spawn", EventPlayerSpawn);

    RegConsoleCmd("sm_mri", CommandMRI);

    g_cvDisplayInterval = CreateConVar("eotl_mri_display_interval", "0.5", "How often in seconds to update rage info", FCVAR_NONE, true, 0.1);
    g_cvXOffset = CreateConVar("eotl_mri_display_x", "0.01", "X location percent for text (0.0 to 1.0)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvYOffset = CreateConVar("eotl_mri_display_y", "0.5", "Y location percent for text (0.0 to 1.0)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvDebug = CreateConVar("eotl_mri_debug", "0", "0/1 enable debug output", FCVAR_NONE, true, 0.0, true, 1.0);

    g_hClientCookies = RegClientCookie("mri enabled", "mri enabled", CookieAccess_Private);
    g_hHudSync = CreateHudSynchronizer();
}

public void OnMapStart() {
    for(int client = 1; client <= MaxClients; client++) {
        g_PlayerStates[client].enabled = false;
        g_PlayerStates[client].class = TFClass_Unknown;
        g_PlayerStates[client].buffType = BUFF_TYPE_NONE;
    }
    LogDebug("Creating timer with %.1f second interval", g_cvDisplayInterval.FloatValue);
    CreateTimer(g_cvDisplayInterval.FloatValue, DisplayRage, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientConnected(int client) {
    g_PlayerStates[client].enabled = false;
    g_PlayerStates[client].class = TFClass_Unknown;
    g_PlayerStates[client].buffType = BUFF_TYPE_NONE;
}

public void OnClientCookiesCached(int client) {
    LoadClientConfig(client);
}

public Action EventPlayerSpawn(Handle event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_PlayerStates[client].class = TF2_GetPlayerClass(client);
    g_PlayerStates[client].buffType = BUFF_TYPE_NONE;

    if(g_PlayerStates[client].class != TFClass_Soldier) {
        return Plugin_Continue;
    }

    // soldier, figure out what rage item they have equiped if any
    int weaponEnt = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
    if(!IsValidEntity(weaponEnt)) {
        LogDebug("client: %d GetPlayerWeaponSlot() returned %d", client, weaponEnt);
        return Plugin_Continue;
    }

    int weaponIndex = GetEntProp(weaponEnt, Prop_Send, "m_iItemDefinitionIndex");
    if(weaponIndex < 0) {
        LogDebug("client: %d m_iItemDefinitionIndex returned %d", client, weaponIndex);
        return Plugin_Continue;
    }

    // values come from scripts/items/items_game.txt
    switch(weaponIndex) {

        //  129 = The Buff Banner
        // 1001 = Festive Buff Banner
        case 129, 1001:
        {
            LogDebug("%N is using buff banner", client);
            g_PlayerStates[client].buffType = BUFF_TYPE_BUFF_BANNER;
        }

        //  226 = The Battalion's Backup
        case 226:
        {
            LogDebug("%N is using battalions backup", client);
            g_PlayerStates[client].buffType = BUFF_TYPE_BATTALIONS_BACKUP;
        }

        //  354 = The Concheror
        case 354:
        {
            LogDebug("%N is using concheror", client);
            g_PlayerStates[client].buffType = BUFF_TYPE_CONCHEROR;
        }
    }

    return Plugin_Continue;
}

public Action CommandMRI(int client, int args) {
    char argv[32];

    if(args > 1) {
        PrintToChat(client, "\x01[\x03mri\x01] !mri to enable, !mri disable to disable medic rage info");
        return Plugin_Handled;
    }

    if(args == 0) {
        g_PlayerStates[client].enabled = true;
        SaveClientConfig(client);
        PrintToChat(client, "\x01[\x03mri\x01] medic rage info is \x03enabled\x01 for you");
        return Plugin_Handled;
    }

    GetCmdArg(1, argv, sizeof(argv));
    StringToLower(argv);

    if(StrEqual(argv, "disable")) {
        g_PlayerStates[client].enabled = false;
        SaveClientConfig(client);
        PrintToChat(client, "\x01[\x03mri\x01] medic rage info is \x03disabled\x01 for you");
        return Plugin_Handled;
    }

    PrintToChat(client, "\x01[\x03mri\x01] !mri to enable, !mri disable to disable medic rage info");
    return Plugin_Handled;
}

public Action DisplayRage(Handle timer, int junk) {
    for(int client = 1; client <= MaxClients; client++) {

        if(!IsClientInGame(client) || !IsPlayerAlive(client)) {
            continue;
        }

        if(IsFakeClient(client)) {
            continue;
        }

        if(g_PlayerStates[client].class != TFClass_Medic) {
            continue;
        }

        if(!g_PlayerStates[client].enabled) {
            continue;
        }

        int target = GetHealingTarget(client);
        if(target <= 0) {
            LogDebug("%N is not healing anyone", client);
            continue;
        }

        if(g_PlayerStates[target].class != TFClass_Soldier) {
            LogDebug("%N is not healing a soldier (%N)", client, target);
            continue;
        }

        if(g_PlayerStates[target].buffType == BUFF_TYPE_NONE) {
            LogDebug("%N is not using rage weapon", target);
            continue;
        }

        float ragePercent = GetEntPropFloat(target, Prop_Send, "m_flRageMeter");

        SetHudTextParams(g_cvXOffset.FloatValue, g_cvYOffset.FloatValue, g_cvDisplayInterval.FloatValue, 240, 240, 240, 255);
        ShowSyncHudText(client, g_hHudSync, "%N's %s (%.0f%%)", target, g_sRageWeapons[g_PlayerStates[target].buffType], ragePercent);
    }
    return Plugin_Continue;
}

int GetHealingTarget(int client) {
    char weaponClass[64];

    int weaponEnt = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if(weaponEnt <= 0) {
        return -1;
    }

    GetEntityNetClass(weaponEnt, weaponClass, sizeof(weaponClass));
    if(!StrEqual(weaponClass, "CWeaponMedigun")) {
        return -1;
    }

    if(!GetEntProp(weaponEnt, Prop_Send, "m_bHealing")) {
        return -1;
    }

    return GetEntPropEnt(weaponEnt, Prop_Send, "m_hHealingTarget");
}

void LoadClientConfig(int client) {
    if(IsFakeClient(client)) {
        return;
    }

    char enableState[6];
    GetClientCookie(client, g_hClientCookies, enableState, 6);
    if(StrEqual(enableState, "true")) {
        g_PlayerStates[client].enabled = true;
    } else {
        g_PlayerStates[client].enabled = false;
    }

    LogDebug("client: %N has mri %s", client, g_PlayerStates[client].enabled ? "enabled" : "disabled");
}

void SaveClientConfig(int client) {
    char enableState[6];
    if(g_PlayerStates[client].enabled) {
        Format(enableState, 6, "true");
    } else {
        Format(enableState, 6, "false");
    }

    LogDebug("client: %N saving mri as %s", client, g_PlayerStates[client].enabled ? "enabled" : "disabled");
    SetClientCookie(client, g_hClientCookies, enableState);
}

void StringToLower(char[] string) {
    int len = strlen(string);

    for(int i = 0;i < len;i++) {
        string[i] = CharToLower(string[i]);
    }
}

void LogDebug(char []fmt, any...) {

    if(!g_cvDebug.BoolValue) {
        return;
    }

    char message[128];
    VFormat(message, sizeof(message), fmt, 2);
    LogMessage(message);
}