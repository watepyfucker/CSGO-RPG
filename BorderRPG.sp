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
#define NEXTLVXP(%1) (GetConVarInt(g_lvup_need_xp) * g_lv[%1])
#define KILL_T_XP		GetConVarInt(g_kill_T_xp)
#define KILL_T_MONEY 	GetConVarInt(g_kill_T_money)

#define JOB_NUM 3

new const String:g_job_name[][] = {"无职业", "精灵", "游侠", "医师"}

//玩家属性
new g_lv[MAXPLAYER]					//等级
new g_xp[MAXPLAYER]					//经验值
new g_sp[MAXPLAYER]					//技能点
new g_mete[MAXPLAYER]				//转生

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

//Convars
new Handle:g_RespawnTime_CT				//CT复活时间
new Handle:g_lvup_need_xp				//升级需要的经验值(基础量)
new Handle:g_kill_T_xp						//杀死T获得的经验(基础量)
new Handle:g_kill_T_money				//杀死T获得的金钱(基础量)

//Timers
new Handle:g_RespawnTimer[MAXPLAYER]

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
	new String:Game_Name[16];
	GetGameFolderName(Game_Name, sizeof(Game_Name))
	if(!StrEqual(Game_Name, "csgo", false))
		SetFailState("不是CSGO你玩JB")
	
	//读取字典
	LoadTranslations("BorderRPG.phrases");
	
	//初始化
	EventsInit()
	CvarsInit()
	CommandInit()
	
}

/*
===================================
		
		   初始化
		
===================================
*/
public EventsInit()
{
	HookEvent("round_start", Event_RoundStart)
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre)
	HookEvent("player_spawn", Event_PlayerSpawn)
	HookEvent("player_death", Event_PlayerDeath)
}

public CvarsInit()
{
	g_RespawnTime_CT = CreateConVar("rpg_respawntime_ct", "60.0", "CT死亡后多久复活");
	g_lvup_need_xp = CreateConVar("rpg_xp_lvup", "100", "升级所需经验值(基础量)");
	g_kill_T_xp = CreateConVar("rpg_kill_t_get_xp", "10", "杀死T获得的经验(基础量)");
	g_kill_T_money = CreateConVar("rpg_kill_t_get_money", "10", "杀死T获得的金钱(基础量)");
}

public CommandInit()
{
	AddCommandListener(Command_JoinTeam, "jointeam"); 
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
		g_xp[client] = 0
		g_lv[client] = 1
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
	
	if(!IsClientConnected(attacker) || IsFakeClient(attacker))
		return Plugin_Continue;
	
	PrintHintText(attacker, "<font color='#FF6600'>    -%dHP</font>", damage)
	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	new teamA = GetClientTeam(victim);
	new teamB = GetClientTeam(killer);
	
	if(teamA == teamB || teamB == CS_TEAM_T || IsFakeClient(killer))
		return Plugin_Continue
	
	if(teamA == CS_TEAM_CT)
	{
		g_AliveTeam--;
		g_RespawnTimer[victim] = CreateTimer(GetConVarFloat(g_RespawnTime_CT), Timer_Respawn, victim);
		PrintHintText(victim, "<font color='#66ccff'>[RPGMOD]</font><font color='#66ff00'>%T</font>", "Dead_CT",LANG_SERVER)
	}
	
	if(teamB == CS_TEAM_CT && teamA == CS_TEAM_T)
	{
		g_xp[killer] += KILL_T_XP
		PrintToChat(killer,"\x01 \x03[RPGmod]\x02%d/%i", g_xp[killer],NEXTLVXP(killer));
		if(g_xp[killer] >= NEXTLVXP(killer))
		{
			g_lv[killer] += 1
			g_xp[killer] = 0
			PrintToChat(killer,"\x01 \x03[RPGmod]\x02%T", "LevelUp",LANG_SERVER,g_lv[killer]);
		}
			
	}

	return Plugin_Continue;
}

/*
===================================
		
			Tasks
		
===================================
*/

public Action:Timer_Respawn(Handle:Timer, any:client)
{
	CS_RespawnPlayer(client);
}

/*
===================================
		
		   客户端命令
		
===================================
*/

public Action:Command_JoinTeam(client, const String:command[], args)
{
	if (!IsClientConnected(client)) 
        return Plugin_Continue; 
	
	CS_SwitchTeam(client, CS_TEAM_CT)
	return Plugin_Stop;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (buttons & IN_SPEED)
	{
		//MenuShow_MainMenu(client)
		//SHOWMENU
	}
	return Plugin_Continue
}

/*
===================================
		
		   Menu
		
===================================
*/
/*public Action:MenuShow_MainMenu(id)
{
	new Handle:menu = CreateMenu(MenuHandler_MainMenu);
	decl String:MenuTitle[200]
	Format(MenuTitle, sizeof(MenuTitle), "%T ", "MainMenu_Title", LANG_SERVER, 
	g_lv[id], g_money[id], g_job_name[g_job[id]], g_xp[id], NEXTLVXP(id), g_mete[id], g_sp[id], g_str[id], g_agi[id], g_hea[id], g_end[id], g_int[id], g_luc[id])
	
	//等级:Lv.%d 金钱:$%d 职业:%s \n经验:%d/%d 转生:%d转 属性点:%d \n力量:%d 敏捷:%d 生命:%d 耐力:%d 智力:%d 运气:%d
	SetMenuTitle(menu, MenuTitle)
	
	
	decl String:Item[64]
	Format(Item, sizeof(Item), "%T ", "SkillMenu_Title", LANG_SERVER);
	AddMenuItem(menu, "#Choice1", Item);
	
	SetMenuExitButton(menu, false);
	DisplayMenu(menu, id, MENU_TIME_FOREVER);
}

public MenuHandler_MainMenu(Handle:menu, MenuAction:action, param1, param2)
{
	
}*/