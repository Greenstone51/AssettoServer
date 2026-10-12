using System.Threading.Tasks;
using AssettoServer.Server.Configuration;
using AssettoServer.Server.UserGroup;

namespace AssettoServer.Server.Admin;

public class AdminService : IAdminService
{
    private readonly IUserGroup _userGroup;

    public AdminService(ACServerConfiguration configuration, UserGroupManager userGroupManager)
    {
        _userGroup = userGroupManager.Resolve(configuration.Extra.AdminUserGroup);
    }

    public async Task<bool> IsAdminAsync(ulong guid)
    {
        return await _userGroup.ContainsAsync(guid);
    }
}
