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

<<<<<<< Updated upstream
    internal static bool IsAnimation(string path)
=======
    internal static string IsAnimation(string path)
>>>>>>> Stashed changes
    {
        const string pyScript = "pil_load_animation";
        using (Py.GIL())
        {
            try
            {
                dynamic script = Py.Import(pyScript);
                dynamic _result = script.is_animation(path);
<<<<<<< Updated upstream
                return (bool)_result;
=======
                return (string)_result;
>>>>>>> Stashed changes
            }
            catch (PythonException pye)
            {
                GD.Print(pye);
<<<<<<< Updated upstream
                return false;
=======
                return "F?null";
>>>>>>> Stashed changes
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