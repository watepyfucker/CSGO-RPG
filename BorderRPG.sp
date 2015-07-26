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
#include <cstrike>

#define MAXPLAYER 65

//玩家属性
new g_lv[MAXPLAYER]					//等级
new g_xp[MAXPLAYER]					//经验值
new g_sp[MAXPLAYER]					//技能点

new g_str[MAXPLAYER]				//力量
new g_agi[MAXPLAYER]				//敏捷
new g_int[MAXPLAYER]				//智力
new g_hea[MAXPLAYER]				//生命
new g_end[MAXPLAYER]				//耐力
new g_luc[MAXPLAYER]				//运气

new g_money[MAXPLAYER]				//金钱
new g_job[MAXPLAYER]				//职业

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
	GetGameFolderName(Game_Name, sizeof(Game_Name))
	if(!StrEqual(Game_Name, "csgo", false))
		SetFailState("不是CSGO你玩JB")
	
	HookEvent("round_start", Event_RoundStart)
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre)
	HookEvent("player_death", Event_PlayerDeath)
	
	AddCommandListener(Command_JoinTeam, "jointeam"); 
	LoadTranslations("BorderRPG.phrases");
}

public Action:Event_RoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	//1 白 2深红 3紫 4绿 5淡绿 6橄榄绿 7红淡一点 8淡紫 9淡黄 10咖啡色
	PrintToChatAll("\x01 \x03[RPGmod]\x02%T", "GameStart", LANG_SERVER);
	PrintHintTextToAll("<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","GameStart",LANG_SERVER);
	PrintCenterTextAll("<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","GameStart",LANG_SERVER);
}

public Action:Event_PlayerHurt(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"))
	new damage = GetEventInt(event, "dmg_health")
	
	PrintHintText(attacker, "<font color='#FF6600'>    -%dHP</font>", damage)
}

public Action:Event_PlayerDeath(Handle:event, String:event_name[], bool:dontBroadcast)
{
	
}

public Action:Command_JoinTeam(client, const String:command[], args)
{
	if (!IsClientConnected(client)) 
        return Plugin_Continue; 
	
	CS_SwitchTeam(client, CS_TEAM_CT)
	return Plugin_Stop;
}