/*
1.0
Fixed bug specing a common infected.
Added Pov Modes
1.0.1
Added Toggle Cmds 

1.0.2
changed to PostThink from OnGameFrame

1.1
added Cookiesaving

1.2
Blocking POV mode while boomed and made a workaround for client prediction errors for vomit texture on screen
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#define PLUGIN_VERSION "1.3"


static Handle:hCvar_TpMode = INVALID_HANDLE;
static Handle:hCvar_TpDefault = INVALID_HANDLE;

static bool:bClientPov[MAXPLAYERS+1] = {true, ...};
static Handle:hCookie_PovPerf = INVALID_HANDLE;

static iTpMode = 1;
static bool:bTpModeDefault = true;

static iCamRef[MAXPLAYERS+1];



public Plugin:myinfo =
{
    name = "ThirdPerson_To_POV",
    author = "Lux",
    description = "Turns Thirdperson events in to Point of view",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/showthread.php?p=2518781#post2518781"
};


public OnPluginStart()
{
	hCookie_PovPerf = RegClientCookie("tp_to_pov_cookie", "", CookieAccess_Protected);
	
	CreateConVar("thirdperson_to_pov_version", PLUGIN_VERSION, "Thirdperson to point of view version", FCVAR_NOTIFY|FCVAR_SPONLY);
	hCvar_TpMode = CreateConVar("tp_pov_mode", "1", "Thirdperson to point of view mode (0 = disable 1 = Semi Events(Being Pounced but not when getting up) 2 = full)", FCVAR_NOTIFY);
	hCvar_TpDefault = CreateConVar("tp_pov_default_mode", "1", "Default mode when people join and have no cookie or no cookie option applied, 1 = on | 0 = off", FCVAR_NOTIFY);
	
	RegConsoleCmd("sm_povoff", PovOff, "turns pov off");
	RegConsoleCmd("sm_povon", PovOn, "turns pov on");
	
	HookEvent("player_death", ePlayerCheck, EventHookMode_Pre);
	HookEvent("player_spawn", ePlayerCheck);
	HookEvent("player_team", ePlayerCheck);
	
	HookConVarChange(hCvar_TpMode, eConvarChanged);
	HookConVarChange(hCvar_TpDefault, eConvarChanged);
	
	AutoExecConfig(true, "ThirdPerson_To_POV1.2");
	CvarsChanged();
}

public eConvarChanged(Handle:hCvar, const String:sOldVal[], const String:sNewVal[])
{
	CvarsChanged();
}

CvarsChanged()
{
	iTpMode = GetConVarInt(hCvar_TpMode);
	bTpModeDefault = GetConVarInt(hCvar_TpDefault) > 0;
}

public ePlayerCheck(Handle:hEvent, const String:sEventName[], bool:bDontBroadcast)
{
	static iClient;
	iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(iClient < 1 || iClient > MaxClients)
		return;
	
	if(!IsClientInGame(iClient) || IsFakeClient(iClient))
		return;
	
	static iEntity;
	if(!IsValidEntRef(iCamRef[iClient]))
		return;
	
	iEntity = EntRefToEntIndex(iCamRef[iClient]);
	AcceptEntityInput(iEntity, "Disable", iClient);
	AcceptEntityInput(iEntity, "kill");
	iCamRef[iClient] = -1;
}

public Hook_OnPostThinkPost(i)
{
	if(!IsPlayerAlive(i) || GetClientTeam(i) != 2 || !AreClientCookiesCached(i)) 
		return;
	
	static iEntity;
	
	if(!bClientPov[i] || !IsPlayerAlive(i) || !bShouldBePov(i))
	{
		if(IsValidEntRef(iCamRef[i]))
			return;
			
		iEntity = EntRefToEntIndex(iCamRef[i]);
		AcceptEntityInput(iEntity, "Disable", i);
		AcceptEntityInput(iEntity, "Kill");
		return;
	}
	
	if(IsValidEntRef(iCamRef[i]))
		return;
	
	iEntity = CreateEntityByName("point_viewcontrol_survivor");
	if(iEntity < 1)
		return;
	
	DispatchSpawn(iEntity);
	ActivateEntity(iEntity);
	 
	SetVariantString("!activator"); 
	AcceptEntityInput(iEntity, "SetParent", i);
	SetVariantString("eyes");
	AcceptEntityInput(iEntity, "SetParentAttachment");
	AcceptEntityInput(iEntity, "Enable", i);
	
	TeleportEntity(iEntity, Float:{-4.2, 0.0, 0.0}, NULL_VECTOR, NULL_VECTOR);
	
	iCamRef[i] = EntIndexToEntRef(iEntity);
}

static bool:bShouldBePov(iClient)
{
	switch(iTpMode)
	{
		case 2:
			return bShouldBePov2(iClient);
		case 1:
			return bShouldBePov1(iClient);
	}
	return false;
}

static bool:bShouldBePov2(iClient) 
{
	if(GetEntPropEnt(iClient, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_jockeyAttacker") > 0)
		return true; 
	if(GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_reviveTarget") > 0)
		return true;  
	if(GetEntPropFloat(iClient, Prop_Send, "m_staggerTimer", 1) > -1.0)
		return true; 
	switch(GetEntProp(iClient, Prop_Send, "m_iCurrentUseAction"))
	{
		case 1:
		{
			static iTarget;
			iTarget = GetEntPropEnt(iClient, Prop_Send, "m_useActionTarget");
			
			if(iTarget == GetEntPropEnt(iClient, Prop_Send, "m_useActionOwner"))
				return true;
			else if(iTarget != iClient)
				return true;
		}
		case 4, 6, 7, 8, 9, 10:
			return true;
	}
	
	static String:sModel[31];
	GetEntPropString(iClient, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	
	switch(sModel[29])
	{
		case 'b'://nick
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 626, 625, 624, 623, 622, 621, 661, 662, 664, 665, 666, 667, 668, 670, 671, 672, 673, 674, 620, 680, 616:
					return true;
			}
		}
		case 'd'://rochelle
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 674, 678, 679, 630, 631, 632, 633, 634, 668, 677, 681, 680, 676, 675, 673, 672, 671, 670, 687, 629, 625, 616:
					return true;
			}
		}
		case 'c'://coach
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 656, 622, 623, 624, 625, 626, 663, 662, 661, 660, 659, 658, 657, 654, 653, 652, 651, 621, 620, 669, 615:
					return true;
			}
		}
		case 'h'://ellis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 625, 675, 626, 627, 628, 629, 630, 631, 678, 677, 676, 575, 674, 673, 672, 671, 670, 669, 668, 667, 666, 665, 684, 621:
					return true;
			}
		}
		case 'v'://bill
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 528, 759, 763, 764, 529, 530, 531, 532, 533, 534, 753, 676, 675, 761, 758, 757, 756, 755, 754, 527, 772, 762, 522:
					return true;
			}
		}
		case 'n'://zoey
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 537, 819, 823, 824, 538, 539, 540, 541, 542, 543, 813, 828, 825, 822, 821, 820, 818, 817, 816, 815, 814, 536, 809, 572:
					return true;
			}
		}
		case 'e'://francis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 532, 533, 534, 535, 536, 537, 769, 768, 767, 766, 765, 764, 763, 762, 761, 760, 759, 758, 757, 756, 531, 530, 775, 525:
					return true;
			}
		}
		case 'a'://louis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 529, 530, 531, 532, 533, 534, 766, 765, 764, 763, 762, 761, 760, 759, 758, 757, 756, 755, 754, 753, 527, 772, 528, 522:
					return true;
			}
		}
		case 'w'://adawong
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
			case 674, 678, 679, 630, 631, 632, 633, 634, 668, 677, 681, 680, 676, 675, 673, 672, 671, 670, 687, 629, 625:
					return true;
			}
		}
	}
	
	return false;
}

static bool:bShouldBePov1(iClient) 
{
	if(GetEntPropEnt(iClient, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if(GetEntProp(iClient, Prop_Send, "m_isHangingFromTongue") > 0)
		return true; 
	if(GetEntProp(iClient, Prop_Send, "m_reachedTongueOwner") > 0)
		return true; 
	if(GetEntProp(iClient, Prop_Send, "m_iCurrentUseAction") == 1)
	{
		static iTarget;
		iTarget = GetEntPropEnt(iClient, Prop_Send, "m_useActionTarget");
		
		if(iTarget == GetEntPropEnt(iClient, Prop_Send, "m_useActionOwner"))
			return true;
		else if(iTarget != iClient)
			return true;
	}
	
	return false;
}

static bool:IsValidEntRef(iEntRef)
{
	return (iEntRef != 0 && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE);
}


public Action:PovOff(iClient, iArgs)
{
	if(iClient < 1 || !IsClientInGame(iClient) || IsFakeClient(iClient))
		return Plugin_Continue;
	
	if(AreClientCookiesCached(iClient))
		SetClientCookie(iClient, hCookie_PovPerf, "0");
	
	bClientPov[iClient] = false;
	return Plugin_Continue;
}
public Action:PovOn(iClient, iArgs)
{
	if(iClient < 1 || !IsClientInGame(iClient) || IsFakeClient(iClient))
		return Plugin_Continue;
	
	if(AreClientCookiesCached(iClient))
		SetClientCookie(iClient, hCookie_PovPerf, "1");
	
	bClientPov[iClient] = true;
	return Plugin_Continue;
}

public OnClientCookiesCached(iClient)
{
	if(iClient < 1 || !IsClientConnected(iClient))
		return;
	
	static String:sCookie[3];
	GetClientCookie(iClient, hCookie_PovPerf, sCookie, sizeof(sCookie));
	if(StrEqual(sCookie, "\0", false) || StrEqual(sCookie, "0", false))
	{
		if(bTpModeDefault && StrEqual(sCookie, "\0", false))
			bClientPov[iClient] = true;
		else
			bClientPov[iClient] = false;
	}
	else
	{
		bClientPov[iClient] = true;
	}
}

public OnClientPutInServer(iClient)
{
	if(IsFakeClient(iClient))
		return;
		
	SDKHook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
}
