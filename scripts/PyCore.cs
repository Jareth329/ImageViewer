using System;
using Python.Runtime;
using Godot;

namespace ImageViewer.Python;

public partial class PyCore:Node
{
    private static IntPtr state;

    internal static Core.Error Start()
    {
        try
        {
            Runtime.PythonDLL = "./lib/python-3.12.0-embed-amd64/python312.dll";
            PythonEngine.Initialize();
            state = PythonEngine.BeginAllowThreads();
            return Core.Error.OK;
        }
        catch (PythonException pye)
        {
            Console.WriteLine(pye);
            return Core.Error.Python;
        }
    }

    internal static string IsAnimation(string path)
    {
        const string pyScript = "pil_load_animation";
        using (Py.GIL())
        {
            try
            {
                dynamic script = Py.Import(pyScript);
                dynamic _result = script.is_animation(path);
                return (string)_result;
            }
            catch (PythonException pye)
            {
                GD.Print(pye);
                return "F?null";
            }
        }
    }

    internal static Core.Error LoadAnimation(string path)
    {
        const string pyScript = "pil_load_animation";
        using (Py.GIL())
        {
            try
            {
                dynamic script = Py.Import(pyScript);
                script.get_frames(path);
                return Core.Error.OK;
            }
            catch (PythonException pye)
            {
                GD.Print(pye);
                return Core.Error.Python;
            }
        }
    }

    internal static Core.Error Stop()
    {
        try
        {
            PythonEngine.EndAllowThreads(state);
            PythonEngine.Shutdown();
            return Core.Error.OK;
        }
        catch (PythonException pye)
        {
            Console.WriteLine(pye);
            return Core.Error.Python;
        }
    }
}