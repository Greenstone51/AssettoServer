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

        RuleFor(cfg => cfg.TopLeftX).InclusiveBetween(0f, 1f);
        RuleFor(cfg => cfg.TopLeftY).InclusiveBetween(0f, 1f);
        RuleFor(cfg => cfg.BottomRightX).InclusiveBetween(0f, 1f);
        RuleFor(cfg => cfg.BottomRightY).InclusiveBetween(0f, 1f);

        RuleFor(cfg => cfg.BottomRightX).GreaterThan(cfg => cfg.TopLeftX)
            .WithMessage("BottomRightX must be greater than TopLeftX");
        RuleFor(cfg => cfg.BottomRightY).GreaterThan(cfg => cfg.TopLeftY)
            .WithMessage("BottomRightY must be greater than TopLeftY");
    }
}
