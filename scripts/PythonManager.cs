using Godot;

namespace ImageViewer.Python;

public partial class PythonManager : Node
{
    private ImageManager? imageManager;

    public PythonManager()
    {
        var mainloop = Engine.GetMainLoop();
        var scenetree = mainloop as SceneTree;
        scenetree!.Root.CallDeferred("add_child", this);
    }

    public override void _Ready()
    {
        imageManager = GetNode<ImageManager>("/root/ImageManager");
    }

    public void SendImageInfo(dynamic d_info)
    {
        string info = (string)d_info;
        CallDeferred("SendImageInfo", info);
    }

    private void SendImageInfo(string info)
    {
        imageManager!.SendImageInfo(info);
    }

    public void SendAnimationFrame(dynamic d_frame)
    {
        string frame = (string)d_frame;
        CallDeferred("SendAnimationFrame", frame);
        //imageManager!.SendAnimationFrame(frame);
    }

    private void SendAnimationFrame(string frame)
    {
        imageManager!.SendAnimationFrame(frame);
    }

    /*public void SendImageTile(dynamic d_tile)
    {
        string tile = (string)d_tile;
        imageManager.SendImageTile(tile);
    }*/

    public bool StopLoading(dynamic d_path)
    {
        string path = (string)d_path;
        return (bool)CallDeferred("StopLoading", path);// (bool)imageManager!.CallDeferred("StopLoading", path);
    }

    private bool StopLoading(string path)
    {
        return imageManager!.StopLoading(path);
    }
}
