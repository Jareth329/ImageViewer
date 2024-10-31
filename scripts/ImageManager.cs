using Godot;

namespace ImageViewer;

public partial class ImageManager : Node
{
    private Control? main;

    public override void _Ready()
    {
        main = GetNode<Control>("/root/main");
    }

    internal bool StopLoading(string path)
    {
        string currPath = (string)main!.Call("get_current_path");
        path = path.Replace('\\', '/');
        if (string.IsNullOrWhiteSpace(currPath))
        {
            return true;
        }
        if (currPath.Equals(path, System.StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }
        return true;
    }

    internal void SendImageInfo(string info)
    {
        string[] sections = info.Split("?");
        main!.Call("set_animation_info", int.Parse(sections[0]), 24, sections[1]);
    }

    private ImageTexture? GetImageTexture(string data, string type, string path)
    {
        byte[] bytes = System.Convert.FromBase64String(data);
        var image = new Image();
        if (type.Equals("jpeg", System.StringComparison.OrdinalIgnoreCase))
        {
            var error = image.LoadJpgFromBuffer(bytes);
            if (StopLoading(path) || error != Error.Ok) return null;
        }
        else {
            var error = image.LoadWebpFromBuffer(bytes);
            if (StopLoading(path) || error != Error.Ok) return null;
        }
        return ImageTexture.CreateFromImage(image);
    }

    internal void SendAnimationFrame(string frame)
    {
        string[] sections = frame.Split("?");
        string type = sections[0], path = sections[1], data = sections[3];

        if (StopLoading(path)) return;

        float delay;
        if (int.TryParse(sections[2], out int temp)) delay = (float)temp / 1000;
        else delay = (float)double.Parse(sections[2]) / 1000;

        var texture = GetImageTexture(data, type, path);
        if (StopLoading(path) || texture is null) return;
        main!.Call("add_animation_frame", texture, delay);
    }

    /*private int currentGridIndex = 0;
    internal void SendImageTile(string tile)
    {
        string[] sections = tile.Split("?");
        string path = sections[0], data = sections[1];
        if (StopLoading(path)) return;

        var texture = GetImageTexture(data, path);
        if (StopLoading(path) || texture is null) return;
        signals.Call("emit_signal", "add_large_image_section", texture, path, currentGridIndex);
        currentGridIndex++;
    }*/
}

