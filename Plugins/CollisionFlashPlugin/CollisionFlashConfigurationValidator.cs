using FluentValidation;
using JetBrains.Annotations;

namespace CollisionFlashPlugin;

[UsedImplicitly]
public class CollisionFlashConfigurationValidator : AbstractValidator<CollisionFlashConfiguration>
{
    public CollisionFlashConfigurationValidator()
    {
        RuleFor(cfg => cfg.DurationSeconds).InclusiveBetween(0.05f, 10f);
        RuleFor(cfg => cfg.Opacity).InclusiveBetween(0f, 1f);
        RuleFor(cfg => cfg.ShowInPits).NotNull();
    }
}
