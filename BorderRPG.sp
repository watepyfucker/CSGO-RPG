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
new Handle:g_RespawnTimer[MAXPLAYER]			//复活
new Handle:g_PlayerThinkTimer[MAXPLAYER]	//Think

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
	AddCommandListener(Command_Test, "sm_testa"); 
}

/*
===================================
		
		   各种事件
		
===================================
*/

//回合开始
public Action:Event_RoundStart(Handle:event, String:event_name[], bool:dontBroadcast)
{
	g_AliveTeam = 0
	//1 白 2深红 3紫 4绿 5淡绿 6橄榄绿 7红淡一点 8淡紫 9淡黄 10咖啡色
	PrintToChatAll("\x01 \x03[RPGmod]\x02%T", "GameStart", LANG_SERVER);
	PrintHintTextToAll("<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","GameStart",LANG_SERVER);
	//PrintCenterTextAll("<font color='#66ccff'>[RPGmod]</font><font color='#66ff00'>%T</font>","GameStart",LANG_SERVER);
}

//玩家复活
public Action:Event_PlayerSpawn(Handle:event,const String:event_name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new team = GetClientTeam(client);
		
	// if(team == CS_TEAM_CT)
	// {
		// g_AliveTeam++;
		// g_xp[client] = 0
		// g_lv[client] = 1
	// }
	return Plugin_Continue;
}

//玩家连接
public OnClientConnected(client)
{
	if(!IsFakeClient(client))
	{
		g_PlayerThinkTimer[client] = CreateTimer(1.0, Timer_PlayerThink, client, TIMER_REPEAT);
	}
}

//玩家断线
public OnClientDisconnect(client)
{
	if(!IsFakeClient(client))
	{
		KillTimer(g_PlayerThinkTimer[client])
		g_PlayerThinkTimer[client] = INVALID_HANDLE;
	}
}

//玩家伤害
public Action:Event_PlayerHurt(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new damage = GetEventInt(event, "dmg_health");
	
	if(!IsClientConnected(attacker) || IsFakeClient(attacker))
		return Plugin_Continue;
	
	PrintHintText(attacker, "<font color='#FF6600'>    -%dHP</font>", damage)
	return Plugin_Continue;
}

//玩家死亡
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
			
	}

	return Plugin_Continue;
}

/*
===================================
		
			Timer
		
===================================
*/

//复活事件
public Action:Timer_Respawn(Handle:Timer, any:client)
{
	CS_RespawnPlayer(client);
}

//Player Think
public Action:Timer_PlayerThink(Handle:Timer, any:client)
{
	if(g_xp[client] >= NEXTLVXP(client))
	{
		g_lv[client] ++
		g_xp[client] -= NEXTLVXP(client)
		PrintToChat(client,"\x01 \x03[RPGmod]\x02%T", "LevelUp",LANG_SERVER,g_lv[client]);
	}
}

/*
===================================
		
		   客户端命令
		
===================================
*/

//Jointeam
public Action:Command_JoinTeam(client, const String:command[], args)
{
	if (!IsClientConnected(client)) 
        return Plugin_Continue; 
	
	CS_SwitchTeam(client, CS_TEAM_CT)
	return Plugin_Stop;
}

//
public Action:Command_Test(client, const String:command[], args)
{
	rpg_Strip_Weapon(client, 1)
	rpg_Give_Weapon_Skin(client, "weapon_ak47", 344)
}

//Button
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (buttons & IN_SPEED)
	{
		MenuShow_MainMenu(client)
		//SHOWMENU
	}
	return Plugin_Continue
}

/*
===================================
		
		   Menu
		
===================================
*/

//Main Menu
public Action:MenuShow_MainMenu(id)
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
	
}

/*
===================================
		
		   各种函数
		
===================================
*/

//皮肤枪
public rpg_Give_Weapon_Skin(client,String:WpnName[], SkinId)
{
	new entity = GivePlayerItem(client,  WpnName);
	new m_iItemIDHigh = GetEntProp(entity, Prop_Send, "m_iItemIDHigh");
	new m_iItemIDLow = GetEntProp(entity, Prop_Send, "m_iItemIDLow");

	SetEntProp(entity,Prop_Send,"m_iItemIDLow",2048);
	SetEntProp(entity,Prop_Send,"m_iItemIDHigh",0);

	SetEntProp(entity,Prop_Send,"m_nFallbackPaintKit", SkinId);
    
	new Handle:pack;
	CreateDataTimer(2.0, RestoreItemID, pack);
	WritePackCell(pack,entity);
	WritePackCell(pack, m_iItemIDHigh);
	WritePackCell(pack, m_iItemIDLow);
}

public Action:RestoreItemID(Handle:timer, Handle:pack)
{
	new entity;
	new m_iItemIDHigh;
	new m_iItemIDLow;
    
	ResetPack(pack);
	entity = ReadPackCell(pack);
	m_iItemIDHigh = ReadPackCell(pack);
	m_iItemIDLow = ReadPackCell(pack);
    
    
	SetEntProp(entity,Prop_Send,"m_iItemIDHigh",m_iItemIDHigh);
	SetEntProp(entity,Prop_Send,"m_iItemIDLow",m_iItemIDLow);
}  

//扒武器
public rpg_Strip_Weapon(client, slot)
{
	if(client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		new WpnEnt
		if((WpnEnt = GetPlayerWeaponSlot(client, slot)) != -1)
		{
			RemovePlayerItem(client, WpnEnt);
			AcceptEntityInput(WpnEnt, "Kill");
		}
	}
}
