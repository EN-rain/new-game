using Godot;

namespace Oozeborne.Interop;

public partial class M0InteropProbe : Node
{
    [Signal]
    public delegate void ProbeCompletedEventHandler(string message);

    [Export]
    public string ProbeLabel { get; set; } = "unset";

    [Export]
    public Resource? SkillResource { get; set; }

    public int LimboCallCount { get; private set; }

    public string echo_from_csharp(string value)
    {
        return $"csharp:{value}";
    }

    public string call_gdscript(Node target, string value)
    {
        return target.Call("echo_from_gdscript", value).AsString();
    }

    public string read_skill_id()
    {
        return SkillResource?.Get("skill_id").AsString() ?? string.Empty;
    }

    public void emit_probe(string marker)
    {
        EmitSignal(SignalName.ProbeCompleted, marker);
    }

    public bool enemy_probe_from_limbo(string marker)
    {
        LimboCallCount++;
        EmitSignal(SignalName.ProbeCompleted, marker);
        return marker == "limbo-to-csharp";
    }

    public int get_limbo_call_count()
    {
        return LimboCallCount;
    }
}
