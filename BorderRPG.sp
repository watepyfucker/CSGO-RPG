/*===========================


			CSGO RPGMOD
				--BorderRPG


============================*/

/*
log:
	15/7/26:Create on github
*/

#include <sourcemod>
#include <sdktools>
#include <adminmenu>

//Mod info
public Plugin:myinfo=
{
	name = "BorderRPG",
	author = "FUCKER",
	description = "BorderRPG mod",
	version = "0.0",
	url = "https://github.com/watepyfucker/CSGO-RPG/"
}

public OnPluginStart()
{
	new String:Game_Name[32];
	GetGameFolderName(Game_Name, sizeof(Game_Name));
	if(!StrEqual(Game_Name, "csgo", false))
		SetFailState("不是CSGO你玩JB");
	
	HookEvent("round_start",			Event_RoundStart);
}

public Action:Event_RoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	PrintToChatAll("\x01M \x02o \x03t \x04h \x05e \x06r \x07F \x08u \x09c \x10k");
}
