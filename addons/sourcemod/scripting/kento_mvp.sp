//***************NYAN CAT****************
//░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
//░░░░░░░░░░▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄░░░░░░░░░
//░░░░░░░░▄▀░░░░░░░░░░░░▄░░░░░░░▀▄░░░░░░░
//░░░░░░░░█░░▄░░░░▄░░░░░░░░░░░░░░█░░░░░░░
//░░░░░░░░█░░░░░░░░░░░░▄█▄▄░░▄░░░█░▄▄▄░░░
//░▄▄▄▄▄░░█░░░░░░▀░░░░▀█░░▀▄░░░░░█▀▀░██░░
//░██▄▀██▄█░░░▄░░░░░░░██░░░░▀▀▀▀▀░░░░██░░
//░░▀██▄▀██░░░░░░░░▀░██▀░░░░░░░░░░░░░▀██░
//░░░░▀████░▀░░░░▄░░░██░░░▄█░░░░▄░▄█░░██░
//░░░░░░░▀█░░░░▄░░░░░██░░░░▄░░░▄░░▄░░░██░
//░░░░░░░▄█▄░░░░░░░░░░░▀▄░░▀▀▀▀▀▀▀▀░░▄▀░░
//░░░░░░█▀▀█████████▀▀▀▀████████████▀░░░░
//░░░░░░████▀░░███▀░░░░░░▀███░░▀██▀░░░░░░
//░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
//***************NYAN CAT****************
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <karyuu>

#define STEAMID_LIMIT 12 // steamids limit per MVP.

int g_iMVPCounter;
int g_iDisplayAt[MAXPLAYERS+1];

ArrayList g_hMVPName;
StringMap g_hMVPPath;
StringMap g_hSteamids;
StringMap g_hMVPFlags;

char g_sSelectedMVP[MAXPLAYERS + 1][64];

Menu g_hMenu;
Handle g_hCookie;

float g_fVolume[MAXPLAYERS + 1];

bool g_bLateLoad;

public Plugin myinfo =
{
	name = "[CS:GO] Custom MVP Anthem",
	author = "Kento, .NiGHT",
	version = "3.2",
	description = "Custom MVP Anthem",
	url = "https://github.com/NiGHT757/Custom-MVP-Anthem"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_mvp", Command_MVP, "Select Your MVP Anthem");
	RegConsoleCmd("sm_mvpvol", Command_MVPVol, "MVP Volume");

	RegAdminCmd("sm_reload_mvps", Command_Reload, ADMFLAG_RCON, "Reload MVP config");

	HookEvent("round_mvp", Event_RoundMVP);

	LoadTranslations("kento.mvp.phrases");

	g_hMVPName = new ArrayList(ByteCountToCells(64));
	g_hMVPPath = new StringMap();
	g_hSteamids = new StringMap();
	g_hMVPFlags = new StringMap();

	g_hCookie = RegClientCookie("mvp_settings", "Player's MVP Anthem", CookieAccess_Private);

	SetCookieMenuItem(Mvp_Settings, 0, "MVP Anthem");

	if(g_bLateLoad)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i) || IsFakeClient(i))
			{
				continue;
			}

			OnClientCookiesCached(i);
		}
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client))	return;

	static char sExplode[2][128];
	GetClientCookie(client, g_hCookie, sExplode[0], sizeof(sExplode[]));
	if(sExplode[0][0])
	{
		ExplodeString(sExplode[0], ";", sExplode, sizeof(sExplode), sizeof(sExplode[])); // sound + volume
		if(sExplode[0][0] && g_hMVPPath.GetString(sExplode[0], "", 1))
		{
			if(UTIL_GetAccess(client, sExplode[0]) && UTIL_GetFlagAccess(client, sExplode[0]))
				strcopy(g_sSelectedMVP[client], sizeof(g_sSelectedMVP[]), sExplode[0]);
			else
				g_sSelectedMVP[client][0] = '\0';
		}
		else{
			g_sSelectedMVP[client][0] = '\0';
		}

		if(sExplode[1][0])
			g_fVolume[client] = StringToFloat(sExplode[1]);
		else
			g_fVolume[client] = 1.0;
	}
	else{
		g_sSelectedMVP[client][0] = '\0';
		g_fVolume[client] = 1.0;
	}
}

public void Mvp_Settings(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if(action == CookieMenuAction_SelectOption)
	{
		DisplayMVPSettings(client);
	}
}

public void OnConfigsExecuted()
{
	LoadConfig();
}

public Action Event_RoundMVP(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsClientInGame(client))
		return Plugin_Continue;

	if(g_sSelectedMVP[client][0])
	{
		char sPath[PLATFORM_MAX_PATH];
		g_hMVPPath.GetString(g_sSelectedMVP[client], sPath, PLATFORM_MAX_PATH);
		for(int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (!IsClientInGame(iClient) || IsFakeClient(iClient))
			{
				continue;
			}
			CPrintToChat(iClient, "%T", "MVP Anthem", client, client, g_sSelectedMVP[client]);
			EmitSoundToClient(iClient, sPath, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NONE, _, g_fVolume[iClient]);
		}
	}
	else
	{
		char sPath[PLATFORM_MAX_PATH], sName[64];
		g_hMVPName.GetString(Karyuu_RandomInt(1, g_iMVPCounter), sName, sizeof(sName));

		g_hMVPPath.GetString(sName, sPath, PLATFORM_MAX_PATH); // find path by mvp name
		for(int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (!IsClientInGame(iClient) || IsFakeClient(iClient))
			{
				continue;
			}
			CPrintToChat(iClient, "%T", "MVP Anthem Random", iClient, sName);
			EmitSoundToClient(iClient, sPath, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NONE, _, g_fVolume[iClient]);
		}
	}
	return Plugin_Continue;
}

void LoadConfig()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/kento_mvp.cfg");

	if(!FileExists(path))
		SetFailState("Can not find config file \"%s\"!", path);
	
	delete g_hMenu;

	g_hMVPName.Clear();
	g_hMVPPath.Clear();
	g_hSteamids.Clear();
	g_hMVPFlags.Clear();

	g_hMenu = new Menu(MenuHandler_ListMVP);
	g_hMenu.AddItem("", "None");
	g_hMenu.ExitBackButton = true;
	KeyValues kv = new KeyValues("MVP");
	kv.ImportFromFile(path);

	// Read Config
	g_iMVPCounter = 1;
	if(kv.GotoFirstSubKey())
	{
		char sName[MAX_NAME_LENGTH], sPath[PLATFORM_MAX_PATH], sData[32];
		int iSteamids[STEAMID_LIMIT];
		int iCounter;
		do
		{
			// index + name
			kv.GetSectionName(sName, sizeof(sName));
			g_hMVPName.PushString(sName);

			// path
			kv.GetString("file", sPath, sizeof(sPath));
			g_hMVPPath.SetString(sName, sPath);
			
			// Menu
			g_hMenu.AddItem(sName, sName);

			// Precache and download
			PrecacheSound(sPath, true);
			Format(sPath, sizeof(sPath), "sound/%s", sPath);
			AddFileToDownloadsTable(sPath);

			//flags
			if(kv.GetString("flags", sData, sizeof(sData)))
				g_hMVPFlags.SetString(sName, sData);
			
			// steamids
			if(kv.JumpToKey("steamids"))
			{
				kv.GotoFirstSubKey();
				iCounter = 0;
				do{
					kv.GetSectionName(sData, sizeof(sData));
					iSteamids[iCounter] = StringToInt(sData);

					iCounter++;
				}
				while(kv.GotoNextKey());
				
				kv.GoBack();
				kv.GoBack();
				g_hSteamids.SetArray(sName, iSteamids, STEAMID_LIMIT);
			}
		}
		while (kv.GotoNextKey());
	}
	g_iMVPCounter = g_hMVPName.Length;
	kv.Rewind();
	delete kv;
}

public Action Command_Reload(int client, int args)
{
	if(!client)
	{
		PrintToServer("[MVP] Config reloaded");
		LoadConfig();
		return Plugin_Handled;
	}
	
	LoadConfig();
	ReplyToCommand(client, "[MVP] Config reloaded");
	return Plugin_Handled;
}

public Action Command_MVP(int client, int args)
{
	if (!IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	DisplayMVPSettings(client);

	return Plugin_Handled;
}

void DisplayMVPSettings(int client)
{
	Menu settings_menu = new Menu(SettingsMenuHandler);
	char mvpmenu[64];
	if(!g_sSelectedMVP[client][0])	FormatEx(mvpmenu, sizeof(mvpmenu), "%T", "No MVP", client);
	else FormatEx(mvpmenu, sizeof(mvpmenu), g_sSelectedMVP[client]);
	settings_menu.SetTitle("%T", "Setting Menu Title", client, mvpmenu, g_fVolume[client]);

	FormatEx(mvpmenu, sizeof(mvpmenu), "%T", "MVP Menu Title", client);
	settings_menu.AddItem("mvp", mvpmenu);
	FormatEx(mvpmenu, sizeof(mvpmenu), "%T", "Vol Menu Title", client);
	settings_menu.AddItem("vol", mvpmenu);

	settings_menu.ExitBackButton = true;
	settings_menu.Display(client, 0);
}

public int SettingsMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(param == 0)
			{
				g_hMenu.SetTitle("%T", "Select MVP Anthem", client, g_sSelectedMVP[client][0] ? g_sSelectedMVP[client] : "No Custom MVP Anthem");

				g_hMenu.Display(client, 0);
			}
			else DisplayVolMenu(client);
		}
		case MenuAction_Cancel:
		{
			if(param == MenuCancel_ExitBack)
			{
				ShowCookieMenu(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public int MVPMenuHandler(Menu menu, MenuAction action, int client,int param)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			menu.GetItem(param, g_sSelectedMVP[client], sizeof(g_sSelectedMVP[]));
			if(!g_sSelectedMVP[client][0])
			{
				CPrintToChat(client, "%T", "No MVP Anthem", client);
			}
			else
			{
				g_hMVPName.GetString(param, g_sSelectedMVP[client], sizeof(g_sSelectedMVP[]));
				CPrintToChat(client, "%T", "MVP Anthem2", client, g_sSelectedMVP[client]);
			}

			SaveClientOptions(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public int MenuHandler_ListMVP(Menu menu, MenuAction action, int client,int param)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sData[64];
			menu.GetItem(param, sData, sizeof(sData));
			g_iDisplayAt[client] = menu.Selection;
			if(sData[0])
			{
				Menu nMenu = new Menu(MenuHandler_Options);
				nMenu.SetTitle("> %s", sData);
				nMenu.AddItem(sData, "Equip", (UTIL_GetAccess(client, sData) && UTIL_GetFlagAccess(client, sData)) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
				nMenu.AddItem(sData, "Preview");
				nMenu.ExitBackButton = true;
				nMenu.Display(client, 0);
			}
			else{
				g_sSelectedMVP[client][0] = '\0';
				CPrintToChat(client, "%T", "Save MVP Anthem - None", client);
				SaveClientOptions(client);
			}
		}
		case MenuAction_Cancel:
		{
			if(param == MenuCancel_ExitBack)
			{
				DisplayMVPSettings(client);
			}
		}
	}
}

public int MenuHandler_Options(Menu menu, MenuAction action, int client,int param)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sData[64], sPath[PLATFORM_MAX_PATH];
			menu.GetItem(param, sData, sizeof(sData));
			g_hMVPPath.GetString(sData, sPath, sizeof(sPath));
			if(!param)
			{
				strcopy(g_sSelectedMVP[client], sizeof(g_sSelectedMVP[]), sData);
				CPrintToChat(client, "%T", "Save MVP Anthem", client, sData);
				
				SaveClientOptions(client);
			}
			else{
				EmitSoundToClient(client, sPath, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NONE, _, g_fVolume[client]);
				CPrintToChat(client, "%T", "Preview", client, sData);
			}
			g_hMenu.SetTitle("%T", "Select MVP Anthem", client, g_sSelectedMVP[client][0] ? g_sSelectedMVP[client] : "No Custom MVP Anthem");
			g_hMenu.DisplayAt(client, g_iDisplayAt[client], MENU_TIME_FOREVER);
		}
		case MenuAction_Cancel:
		{
			if(param == MenuCancel_ExitBack)
			{
				g_hMenu.SetTitle("%T", "Select MVP Anthem", client, g_sSelectedMVP[client][0] ? g_sSelectedMVP[client] : "No Custom MVP Anthem");
				g_hMenu.DisplayAt(client, g_iDisplayAt[client], MENU_TIME_FOREVER);
			}
		}
		case MenuAction_End: delete menu;
	}
}

void DisplayVolMenu(int client)
{
	Menu vol_menu = new Menu(VolMenuHandler);

	char vol[8];

	if(g_fVolume[client])
		FormatEx(vol, sizeof(vol), "%.2f", g_fVolume[client]);
	else
		strcopy(vol, sizeof(vol), "Mute");

	vol_menu.SetTitle("%T", "Vol Menu Title 2", client, vol);

	vol_menu.AddItem("0", "Mute");
	vol_menu.AddItem("0.2", "20%");
	vol_menu.AddItem("0.4", "40%");
	vol_menu.AddItem("0.6", "60%");
	vol_menu.AddItem("0.8", "80%");
	vol_menu.AddItem("1.0", "100%");

	vol_menu.ExitBackButton = true;
	vol_menu.Display(client, 0);
}

public int VolMenuHandler(Menu menu, MenuAction action, int client,int param)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char vol[8];
			menu.GetItem(param, vol, sizeof(vol));
			g_fVolume[client] = StringToFloat(vol);
			CPrintToChat(client, "%T", "Volume 2", client, g_fVolume[client]);

			SaveClientOptions(client);
		}
		case MenuAction_Cancel:
		{
			if(param == MenuCancel_ExitBack)
			{
				DisplayMVPSettings(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public Action Command_MVPVol(int client,int args)
{
	if (!IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	char arg[8];
	float volume;

	if (args < 1)
	{
		CPrintToChat(client, "%T", "Volume 1", client);
		return Plugin_Handled;
	}

	GetCmdArg(1, arg, sizeof(arg));
	volume = StringToFloat(arg);

	if (volume < 0.0 || volume > 1.0)
	{
		CPrintToChat(client, "%T", "Volume 1", client);
		return Plugin_Handled;
	}

	g_fVolume[client] = StringToFloat(arg);
	CPrintToChat(client, "%T", "Volume 2", client, g_fVolume[client]);

	SaveClientOptions(client);
	return Plugin_Handled;
}

void SaveClientOptions(int client)
{
	char sFormat[128];
	FormatEx(sFormat, sizeof(sFormat), "%s;%.2f", g_sSelectedMVP[client], g_fVolume[client]);
	SetClientCookie(client, g_hCookie, sFormat);
}

bool UTIL_GetAccess(int client, const char[] mvpname)
{
	int iArray[STEAMID_LIMIT];
	if(g_hSteamids.GetArray(mvpname, iArray, sizeof(iArray)))
	{
		int steamid = GetSteamAccountID(client);
		for(int i = 0; i < STEAMID_LIMIT; i++)
		{
			if(steamid == iArray[i])
			{
				return true;
			}
		}
		return false;
	}
	return true;
}

bool UTIL_GetFlagAccess(int client, const char[] mvpname)
{
	char sFlags[8];
	if(g_hSteamids.GetString(mvpname, sFlags, sizeof(sFlags)))
	{
		if(GetUserFlagBits(client) & ReadFlagString(sFlags))
			return true;
		return false;
	}
	return true;
}