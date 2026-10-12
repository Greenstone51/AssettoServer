# AssettoServer [![Build status](https://img.shields.io/github/actions/workflow/status/compujuckel/AssettoServer/dotnet.yml?logo=github&label=Build)](https://github.com/compujuckel/AssettoServer/actions/workflows/dotnet.yml) [![Discord](https://img.shields.io/discord/890676433746268231?logo=discord&label=Discord&color=7289da)](https://discord.gg/uXEXRcSkyz) ![GitHub Downloads)](https://img.shields.io/github/downloads/compujuckel/AssettoServer/total?color=gold&label=Downloads) [![Docker Hub](https://img.shields.io/docker/v/compujuckel/assettoserver?logo=docker&label=Docker)](https://hub.docker.com/r/compujuckel/assettoserver)

> **Authentication and DLC Check disabled, for research purposes only.**
>
> This is a modified fork of [compujuckel/AssettoServer](https://github.com/compujuckel/AssettoServer). It removes Steam authentication, the DLC ownership check and Steam Family Sharing detection. Player identities are **not verified**: bans, whitelists and admin rights can be bypassed or spoofed. Do not use it for public or production servers. It is not affiliated with or endorsed by the original authors.

## About
AssettoServer is a custom game server for Assetto Corsa developed with freeroam in mind. It greatly improves upon the default game server by fixing various security issues and providing new features like AI traffic and dynamic weather.

Race and Qualification sessions are in an experimental state and might need more testing.

This is a fork of https://github.com/Niewiarowski/AssettoServer.

## Disclaimer
The modifications in this fork were made entirely by [Claude](https://claude.ai), an AI assistant by Anthropic, following directions from [Greenstone51](https://github.com/Greenstone51). They are provided as is, without any warranty, and are not reviewed or endorsed by the original AssettoServer authors or by Anthropic.

## Documentation
For more information on configuration, admin commands, etc. also check out our [website](https://assettoserver.org/).

## Getting help
If you have trouble setting up a server feel free to visit the #server-troubleshooting channel on our [Discord](https://discord.gg/uXEXRcSkyz).

**Please don't use the Issue tracker for installation help or configuration questions. Also make sure to read the documentation first before asking questions that are already answered there!**

## License
AssettoServer is licensed under the GNU Affero General Public License v3.0, see [LICENSE](https://github.com/compujuckel/AssettoServer/blob/master/LICENSE) for more info.  
Additionally, you must preserve the legal notices and author attributions present in the server.

**Modification notice (AGPL-3.0 section 5):** This version has been modified from the original AssettoServer by Greenstone51, starting 2026-10-12. The changes are recorded in this repository's commit history and consist of removing Steam authentication, the DLC ownership check, Steam Family Sharing support, the Steamworks package dependency, and the related configuration options. The original copyright and license notices below are unchanged. The complete corresponding source code of this modified version is available in this repository.

```
Copyright (C)  2025 Niewiarowski, compujuckel

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.


Additional permission under GNU AGPL version 3 section 7

If you modify this Program, or any covered work, by linking or combining it 
with the Steamworks SDK by Valve Corporation, containing parts covered by the
terms of the Steamworks SDK License, the licensors of this Program grant you
additional permission to convey the resulting work.

Additional permission under GNU AGPL version 3 section 7

If you modify this Program, or any covered work, by linking or combining it 
with plugins published on https://www.patreon.com/assettoserver, the licensors
of this Program grant you additional permission to convey the resulting work.
```
