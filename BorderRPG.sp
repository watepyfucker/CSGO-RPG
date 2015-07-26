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
#define NEXTLVXP(%1) (g_need_xp *g_lv[%1]* g_lv[%1])

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

//存活人数
new g_AliveTeam			//CT存活

//Vars
new g_RespawnTime_CT				//CT复活时间

//Timers
new g_RespawnTimer[MAXPLAYER]

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
	HookEvent("player_spawn", Event_PlayerSpawn)
	HookEvent("player_death", Event_PlayerDeath)
	
	g_RespawnTime_CT = CreateConVar("rpg_respawntime_ct", "60.0", "CT死亡后多久复活");
	
	AddCommandListener(Command_JoinTeam, "jointeam"); 
	
	LoadTranslations("BorderRPG.phrases");
	
}

/*
===================================
		
		   回合开始/结束
		
===================================
*/

public Action:Event_RoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	g_AliveTeam = 0
	//1 白 2深红 3紫 4绿 5淡绿 6橄榄绿 7红淡一点 8淡紫 9淡黄 10咖啡色
	PrintToChatAll("\x01 \x03[RPGmod]\x02%T", "GameStart", LANG_SERVER);
	PrintHintTextToAll("<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","GameStart",LANG_SERVER);
	//PrintCenterTextAll("<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","GameStart",LANG_SERVER);
}

/*
===================================
		
		   玩家出生
		
===================================
*/

public Action:Event_PlayerSpawn(Handle:event,const String:event_name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new team = GetClientTeam(client);
		
	if(team == CS_TEAM_CT)
		g_AliveTeam++;
	return Plugin_Continue;
}

/*
===================================
		
		   玩家伤害/死亡
		
===================================
*/

public Action:Event_PlayerHurt(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new damage = GetEventInt(event, "dmg_health");
	
	if(!IsClientConnected(attacker))
		return Plugin_Continue;
	
	PrintHintText(attacker, "<font color='#FF6600'>    -%dHP</font>", damage)
	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	new team = GetClientTeam(client);
	new teama = GetClientTeam(killer);
	
	if(team == CS_TEAM_CT)
	{
		g_AliveTeam--;
		if(g_AliveTeam < 1)
		{
			for(int i = 0;i < MAXPLAYER;i++)
			{
				if(g_RespawnTimer[i])
				{
					KillTimer(g_RespawnTimer[i],true);
				}
			}
			return Plugin_Stop;
		}
		else
		{
			g_RespawnTimer[client] = CreateTimer(GetConVarFloat(g_RespawnTime_CT), Respawn, client, TIMER_FLAG_NO_MAPCHANGE);
			PrintHintText(client, "<font color='#66ccff'>[RPGMOD]</font><font color='#66ff00'>%T</font>", "Dead_CT",LANG_SERVER)
		}
	}
	return Plugin_Continue;
}

/*
===================================
		
			Tasks
		
===================================
*/

public Action:Respawn(Handle:Timer, any:client)
{
	CS_RespawnPlayer(client);
}

/*
===================================
		
		   队伍相关
		
===================================
*/

public Action:Command_JoinTeam(client, const String:command[], args)
{
	if (!IsClientConnected(client)) 
        return Plugin_Continue; 
	
	CS_SwitchTeam(client, CS_TEAM_CT)
	return Plugin_Stop;
}