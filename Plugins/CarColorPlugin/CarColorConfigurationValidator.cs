using FluentValidation;

namespace CarColorPlugin;

public class CarColorConfigurationValidator : AbstractValidator<CarColorConfiguration>
{
    public CarColorConfigurationValidator()
    {
        RuleFor(x => x.ChangeCooldownSeconds)
            .InclusiveBetween(0, 60)
            .WithMessage("ChangeCooldownSeconds must be between 0 and 60 seconds");

        RuleFor(x => x.Presets)
            .NotEmpty()
            .WithMessage("Presets must not be empty");

        RuleFor(x => x.BodyMaterialNames)
            .NotEmpty()
            .WithMessage("BodyMaterialNames must not be empty");
    }
}
