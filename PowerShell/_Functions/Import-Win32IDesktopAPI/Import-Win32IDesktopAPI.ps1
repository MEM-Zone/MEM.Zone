#region Function Import-Win32IDesktopAPI
Function Import-Win32IDesktopAPI {
<#
.SYNOPSIS
    Imports the Win32 IDesktop interface.
.DESCRIPTION
    Imports the Win32 IDesktop API so it can be used in PowerShell.
.EXAMPLE
    Import-Win32IDesktopAPI
.EXAMPLE
    [string]$SlideshowDirection = 'Forward'
    [string]$WallpaperPath = 'SomePath\SomeImage.jpg'
    [string]$WallpaperPosition = 'Stretch'
    [string]$WallpaperFolder = 'SomePath'
    [int]$DisplayIndex = 0
    [array]$ShellItemArray = $null

    Import-Win32IDesktopAPI

    ## Monitor Command
    $Command = New-Object -TypeName 'MEMZone.MonitorCommand'

    $Command::GetMonitor()
    $Command::GetMonitorCount()
    $Command::GetMonitorID($DisplayIndex)
    $Command::GetMonitorRECT($DisplayIndex)

    ## Wallpaper Command
    $Command = New-Object -TypeName 'MEMZone.WallpaperCommand'

    $Command::SetWallpaper($DisplayIndex, $WallpaperPath, $WallpaperPosition)
    $Command::GetWallpaper($DisplayIndex)
    $Command::GetWallpaperPosition()
    $Command::SetWallpaperPosition($WallpaperPosition)
    $Command::SetBackgroundColor(0)
    $Command::GetBackgroundColor()
    $Command::AdvanceSlideshow(0, $SlideshowDirection)
    $Command::EnableWallpaper(0)
    $Command::GetSlideshowStatus()
    $Command::SetSlideshowOptions('EnableShuffle', 600)
    $Command::SetSlideshowPath($WallpaperFolder)

    ## File System Command
    $Command = New-Object -TypeName 'MEMZone.FileSystemCommand'

    $Command::ILCreateFromPath($WallpaperFolder)
    $Command::SHCreateShellItemArrayFromIDLists(1, $Command::ILCreateFromPath($WallpaperFolder), [ref]$ShellItemArray)
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
    Credit to Adrian Hum and Federico Paolillo

    This is an private function should tipically not be called directly.
.LINK
    https://docs.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-idesktopwallpaper
.LINK
    https://gist.github.com/LGM-AdrianHum/5dd61cd64377e725393a6b5b62b1d431
.LINK
    https://github.com/federico-paolillo/set-wallpaper
.LINK
    https://MEM.Zone/Import-Win32IDesktopAPI
.LINK
    https://MEM.Zone/Import-Win32IDesktopAPI-CHANGELOG
.LINK
    https://MEM.Zone/Import-Win32IDesktopAPI-GIT
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Win32 API
.FUNCTIONALITY
    Import IDesktop API
#>
    [CmdletBinding()]
    Param ()

    Begin {

        #region VariableDeclaration
        [string[]]$ReferencedAssemblies = @('System.Windows.Forms','System.Drawing', 'System.Management', 'System.Management.Automation')
        [string]$TypeDefinition =
@'
        using System.Collections.Generic;
        using System;
        using System.IO;
        using System.Text;
        using System.Drawing;
        using System.Globalization;
        using System.Windows.Forms;
        using System.Runtime.InteropServices;
        using System.Management;
        using System.Management.Automation;
        using System.Linq;
        using Microsoft.Win32;
        using MEMZone;
        using MEMZone.Helpers;
        using MEMZone.COM;
        using MEMZone.Output;

        namespace MEMZone.Helpers {

            // <summary>
            //     This structure used to resolve HRESULT responses.
            // </summary>
            public enum HRESULT : int {
                S_OK = 0,
                S_FALSE = 1,
                E_ABORT = unchecked((int)0x80004004),
                E_ACCESSDENIED = unchecked((int)0x80070005),
                E_FAIL = unchecked((int)0x80004005),
                E_HANDLE = unchecked((int)0x80070006),
                E_INVALIDARG = unchecked((int)0x80070057),
                E_NOINTERFACE = unchecked((int)0x80004002),
                E_NOTIMPL = unchecked((int)0x80004001),
                E_OUTOFMEMORY = unchecked((int)0x8007000E),
                E_POINTER = unchecked((int)0x80004003),
                E_UNEXPECTED = unchecked((int)0x8000FFFF),
            }

            // <summary>
            //     This structure used to get the display rectangle coordinates.
            // </summary>
            [StructLayout(LayoutKind.Sequential)]
            public struct Rect {
                public int Left;
                public int Top;
                public int Right;
                public int Bottom;
            }

            // <summary>
            //     This enumeration indicates the wallpaper position for all monitors. (This includes when slideshows are running.)
            //     The wallpaper position specifies how the image that is assigned to a monitor should be displayed.
            // </summary>
            public enum WallpaperPosition {
                Center = 0,
                Tile = 1,
                Stretch = 2,
                Fit = 3,
                Fill = 4,
                Span = 5,
            }

            // <summary>
            //     This enumeration is used to set and get slideshow options.
            // </summary>
            public enum SlideshowOptions {
                DisableShuffle = 0,
                EnableShuffle = 0x01,
            }

            // <summary>
            //     This enumeration is used by GetStatus to indicate the current status of the slideshow.
            // </summary>
            [Flags]
            public enum SlideshowState {
                Disabled = 0,
                Enabled = 1,
                Slideshow = 2,
                DisabledByRemoteSession = 4,
            }

            // <summary>
            //     This enumeration is used by the AdvanceSlideshow method to indicate whether to advance the slideshow forward or backward.
            // </summary>
            public enum SlideshowDirection {
                Forward = 0,
                Backward = 1,
            }

            // <summary>
            //     This enumeration is used in the IShellItem interface by the GetDisplayName method.
            // </summary>
            public enum SIGDN : int {
                SIGDN_NORMALDISPLAY = 0x0,
                SIGDN_PARENTRELATIVEPARSING = unchecked((int)0x80018001),
                SIGDN_DESKTOPABSOLUTEPARSING = unchecked((int)0x80028000),
                SIGDN_PARENTRELATIVEEDITING = unchecked((int)0x80031001),
                SIGDN_DESKTOPABSOLUTEEDITING = unchecked((int)0x8004C000),
                SIGDN_FILESYSPATH = unchecked((int)0x80058000),
                SIGDN_URL = unchecked((int)0x80068000),
                SIGDN_PARENTRELATIVEFORADDRESSBAR = unchecked((int)0x8007C001),
                SIGDN_PARENTRELATIVE = unchecked((int)0x80080001)
            }

            // <summary>
            //     This enumeration is used in the IShellItemArray interface by the GetPropertyStore method.
            // </summary>
            public enum GETPROPERTYSTOREFLAGS {
                GPS_DEFAULT = 0,
                GPS_HANDLERPROPERTIESONLY = 0x1,
                GPS_READWRITE = 0x2,
                GPS_TEMPORARY = 0x4,
                GPS_FASTPROPERTIESONLY = 0x8,
                GPS_OPENSLOWITEM = 0x10,
                GPS_DELAYCREATION = 0x20,
                GPS_BESTEFFORT = 0x40,
                GPS_NO_OPLOCK = 0x80,
                GPS_PREFERQUERYPROPERTIES = 0x100,
                GPS_EXTRINSICPROPERTIES = 0x200,
                GPS_EXTRINSICPROPERTIESONLY = 0x400,
                GPS_MASK_VALID = 0x7FF
            }

            // <summary>
            //     This enumeration is used in the IShellItemArray interface by the GetAttributes method.
            // </summary>
            public enum SIATTRIBFLAGS {
                SIATTRIBFLAGS_AND = 0x1,
                SIATTRIBFLAGS_OR = 0x2,
                SIATTRIBFLAGS_APPCOMPAT = 0x3,
                SIATTRIBFLAGS_MASK = 0x3,
                SIATTRIBFLAGS_ALLITEMS = 0x4000
            }

            // <summary>
            //     This enumeration is used in the IShellItemArray interface by the GetPropertyDescriptionList method.
            // </summary>
            [StructLayout(LayoutKind.Sequential, Pack = 4)]
            public struct REFPROPERTYKEY {
                private Guid fmtid;
                private int pid;
                public Guid FormatId {
                    get { return this.fmtid; }
                }
                public int PropertyId {
                    get { return this.pid; }
                }
                public REFPROPERTYKEY(Guid formatId, int propertyId) {
                    this.fmtid = formatId;
                    this.pid = propertyId;
                }
                public static readonly REFPROPERTYKEY PKEY_DateCreated = new REFPROPERTYKEY(new Guid("B725F130-47EF-101A-A5F1-02608C9EEBAC"), 15);
            }
        }

        namespace MEMZone.COM {

            [ComImport]
            [Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B")]
            [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
            public interface IDesktopWallpaper {

                HRESULT SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID, [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);

                [return: MarshalAs(UnmanagedType.LPWStr)]
                string GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID);

                [return: MarshalAs(UnmanagedType.LPWStr)]
                string GetMonitorDevicePathAt(uint monitorIndex);

                [return: MarshalAs(UnmanagedType.U4)]
                uint GetMonitorDevicePathCount();

                [return: MarshalAs(UnmanagedType.Struct)]
                Rect GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)] string monitorID);

                HRESULT SetBackgroundColor([MarshalAs(UnmanagedType.U4)] uint color);

                [return: MarshalAs(UnmanagedType.U4)]
                uint GetBackgroundColor();

                HRESULT SetPosition([MarshalAs(UnmanagedType.I4)] WallpaperPosition position);

                [return: MarshalAs(UnmanagedType.I4)]
                WallpaperPosition GetPosition();

                HRESULT GetSlideshowOptions(out SlideshowOptions slideshowOptions, out uint slideshowTick);

                HRESULT SetSlideshow(IShellItemArray items);

                HRESULT AdvanceSlideshow([MarshalAs(UnmanagedType.LPWStr)] string monitorID, [MarshalAs(UnmanagedType.I4)] SlideshowDirection direction);

                HRESULT Enable([MarshalAs(UnmanagedType.Bool)] bool enable);

                [PreserveSig]
                HRESULT SetSlideshowOptions([MarshalAs(UnmanagedType.I4)] SlideshowOptions options, [MarshalAs(UnmanagedType.I4)] uint slideshowTick);

                SlideshowState GetStatus();
            }

            [ComImport]
            [Guid("C2CF3110-460E-4fc1-B9D0-8A1C0C9CC4BD")]
            public class DesktopWallpaper { }

            [ComImport()]
            [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
            [Guid("b63ea76d-1f85-456f-a19c-48159efa858b")]
            public interface IShellItemArray {
                HRESULT BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, ref IntPtr ppvOut);
                HRESULT GetPropertyStore(GETPROPERTYSTOREFLAGS flags, ref Guid riid, ref IntPtr ppv);
                HRESULT GetPropertyDescriptionList(REFPROPERTYKEY keyType, ref Guid riid, ref IntPtr ppv);
                HRESULT GetAttributes(SIATTRIBFLAGS AttribFlags, int sfgaoMask, ref int psfgaoAttribs);
                HRESULT GetCount(ref int pdwNumItems);
                HRESULT GetItemAt(int dwIndex, ref IShellItem ppsi);
                HRESULT EnumItems(ref IntPtr ppenumShellItems);
            }

            [ComImport()]
            [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
            [Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE")]
            public interface IShellItem {
                [PreserveSig()]
                HRESULT BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, ref IntPtr ppv);
                HRESULT GetParent(ref IShellItem ppsi);
                HRESULT GetDisplayName(SIGDN sigdnName, ref System.Text.StringBuilder ppszName);
                HRESULT GetAttributes(uint sfgaoMask, ref uint psfgaoAttribs);
                HRESULT Compare(IShellItem psi, uint hint, ref int piOrder);
            }
        }

        namespace MEMZone.Output {

            // <summary>
            //     Information about a computer monitor installed in this system.
            // </summary>
            public sealed class Monitor {

                public Monitor(uint index, string name, string id, string resolution) {
                    Index = index;
                    Name = name;
                    ID = id;
                    Resolution = resolution;
                }

                public uint Index { get; set; }
                public string Name { get; set; }
                public string ID { get; set; }
                public string Resolution { get; set; }
            }

            // <summary>
            //     Information about a wallpaper currently set on a specific monitor.
            // </summary>
            public sealed class Wallpaper {

                public Wallpaper(uint index, string name, string path, WallpaperPosition position) {
                    Index = index;
                    Name = name;
                    Path = path;
                    Position = position;
                }

                public uint Index { get; set; }
                public string Name { get; set; }
                public string Path { get; set; }
                public WallpaperPosition Position { get; set; }
            }
        }

        namespace  MEMZone {

            // <summary>
            //     Gets monitor information.
            // </summary>
            public class MonitorCommand {

                // <summary>
                //     Gets information for specified or all attached monitors.
                // </summary>
                public static List<Monitor> GetMonitor(uint monitorIndex = 99) {

                    // Variable declaration
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    uint monitorsCount = 0;
                    var monitors = new List<Monitor>();

                    // Get number of monitors
                    monitorsCount = desktopWallpaper.GetMonitorDevicePathCount();
                    // Console.WriteLine("Found {0} monitors.", monitorsCount);

                    // Query all monitors if no monitor index is provided
                    if (monitorIndex == 99) {

                        // Set monitorIndex to 0
                        monitorIndex = 0;

                        foreach (Screen screen in Screen.AllScreens) {

                            // Get monitor name
                            string monitorName = screen.DeviceName.ToString().Split('\\').Last();

                            // Get monitor id
                            string monitorID = GetMonitorID(monitorIndex);

                            // Get monitor bounds
                            string screenBoundsWidth  = screen.Bounds.Width.ToString();
                            string screenBoundsHeight = screen.Bounds.Height.ToString();

                            // Assemble monitor resolution
                            string monitorResolution = screenBoundsWidth + 'x' + screenBoundsHeight;

                            // Build monitor object
                            Monitor monitor = new Monitor(monitorIndex, monitorName, monitorID, monitorResolution);

                            // Add monitor object to monitor list
                            monitors.Add(monitor);

                            // Increment monitor index
                            monitorIndex ++;
                        }
                    }
                    else {

                        // Get monitor name
                        string monitorName =  Screen.PrimaryScreen.DeviceName.ToString().Split('\\').Last();

                        // Get monitor ID
                        string monitorID = GetMonitorID(monitorIndex);

                        // Get monitor bounds
                        string screenBoundsWidth  = Screen.PrimaryScreen.Bounds.Width.ToString();
                        string screenBoundsHeight = Screen.PrimaryScreen.Bounds.Height.ToString();

                        // Assemble monitor resolution
                        string monitorResolution = screenBoundsWidth + 'x' + screenBoundsHeight;

                        // Build monitor object
                        Monitor monitor = new Monitor(monitorIndex, monitorName, monitorID, monitorResolution);

                        // Add monitor object to monitor list
                        monitors.Add(monitor);
                    }

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Return monitor list
                    return monitors;
                }

                // <summary>
                //     Gets monitor rectangle coordinates.
                // </summary>
                public static Rect GetMonitorRECT(uint monitorIndex) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();

                    // Get monitorID
                    string monitorID = GetMonitorID(monitorIndex);

                    // Get monitor display rectangle
                    Rect displayRectangle = desktopWallpaper.GetMonitorRECT(monitorID);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Return wallpaperPosition object
                    return displayRectangle;
                }

                // <summary>
                //     Gets the monitor hardware id.
                // </summary>
                public static string GetMonitorID(uint monitorIndex) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();

                    // Get monitor id
                    string monitorID = desktopWallpaper.GetMonitorDevicePathAt(monitorIndex).ToString();

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Return wallpaperPosition object
                    return monitorID;
                }

                // <summary>
                //     Gets the total attached monitor count.
                // </summary>
                public static uint GetMonitorCount() {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();

                    // Getmonitor counts
                    uint monitorCount = desktopWallpaper.GetMonitorDevicePathCount();

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Return wallpaperPosition object
                    return monitorCount;
                }
            }

            // <summary>
            //     Gets and sets wallpaper information.
            // </summary>
            public class WallpaperCommand {

                // <summary>
                //     Gets the wallpaper for specified or all attached monitors.
                // </summary>
                public static List<Wallpaper> GetWallpaper(uint monitorIndex = 99) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    uint monitorsCount = 0;
                    var wallpapers = new List<Wallpaper>();

                    // Query all monitors if no monitor index is provided
                    if (monitorIndex == 99) {

                        // Set monitorIndex to 0
                        monitorIndex = 0;

                        // Get number of monitors
                        monitorsCount = MonitorCommand.GetMonitorCount();
                        // Console.WriteLine("Found {0} monitors.", monitorsCount);

                        // Cycle trough all monitors and get monitor info
                        foreach (Screen screen in Screen.AllScreens) {

                            // Get monitor ID
                            string monitorID = MonitorCommand.GetMonitorID(monitorIndex);

                            // Get wallpaper path
                            string wallpaperPath = desktopWallpaper.GetWallpaper(monitorID);

                            // Get wallpaper position
                            WallpaperPosition wallpaperPosition = GetWallpaperPosition();

                            // Get monitor Name
                            string monitorName = screen.DeviceName.ToString().Split('\\').Last();

                            // Build wallpaper object
                            Wallpaper wallpaper = new Wallpaper(monitorIndex, monitorName, wallpaperPath, wallpaperPosition);

                            // Add wallpaper object to wallpapers list
                            wallpapers.Add(wallpaper);

                            // Increment monitor index
                            monitorIndex ++;
                        }
                    }
                    else {

                        // Get monitor ID
                        string monitorID = MonitorCommand.GetMonitorID(monitorIndex);

                        // Get wallpaper path
                        string wallpaperPath = desktopWallpaper.GetWallpaper(monitorID);

                        // Get wallpaper position
                        WallpaperPosition wallpaperPosition = GetWallpaperPosition();

                        // Get monitor Name
                        string monitorName =  Screen.PrimaryScreen.DeviceName.ToString().Split('\\').Last();

                        // Build result object
                        Wallpaper wallpaper = new Wallpaper(monitorIndex, monitorName, wallpaperPath, wallpaperPosition);

                        // Add wallpaper object to wallpapers list
                        wallpapers.Add(wallpaper);
                    }

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write wallpaper list
                    return wallpapers;
                }

                // <summary>
                //     Gets the wallpaper position.
                // </summary>
                public static WallpaperPosition GetWallpaperPosition() {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();

                    // Get wallpaper position
                    WallpaperPosition wallpaperPosition = desktopWallpaper.GetPosition();

                    // Release Com Object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Return wallpaperPosition object
                    return wallpaperPosition;
                }

                // <summary>
                //     Gets the background color.
                // </summary>
                public static uint GetBackgroundColor() {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();

                    // Get background color
                    uint backgroundColor = desktopWallpaper.GetBackgroundColor();

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write backgroundColor value
                    return backgroundColor;
                }

                // <summary>
                //     Gets the slideshow state.
                // </summary>
                public static SlideshowState GetSlideshowStatus() {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();

                    // Get slideshow state
                    SlideshowState slideshowState = desktopWallpaper.GetStatus();


                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write slideshowState value
                    return slideshowState;
                }

                // <summary>
                //     Sets the wallpaper and wallpaper position for a specific monitor.
                // </summary>
                public static HRESULT SetWallpaper(uint monitorIndex, string wallpaperPath, string wallpaperPosition) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    HRESULT hResult;

                    // Get monitor ID
                    string monitorID = MonitorCommand.GetMonitorID(monitorIndex);

                    // Set wallpaper and position
                    hResult = desktopWallpaper.SetWallpaper(monitorID, wallpaperPath);
                    hResult = SetWallpaperPosition(wallpaperPosition);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write info to console
                    // Console.WriteLine("MonitorIndex: {0}\nMonitorID: {1}\nWallpaperPath: {2}", monitorIndex, monitorID, wallpaperPath);

                    // Return hResult
                    return hResult;
                }

                // <summary>
                //     Sets the wallpaper position.
                // </summary>
                public static HRESULT SetWallpaperPosition(string wallpaperPosition) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    TextInfo txtInfo = new CultureInfo("en-us", false).TextInfo;
                    HRESULT hResult;

                    // Convert position to titlecase
                    wallpaperPosition = txtInfo.ToTitleCase(wallpaperPosition);

                    // Get wallpaper position enum number value
                    WallpaperPosition wallpaperPositionValue = (WallpaperPosition)Enum.Parse(typeof(WallpaperPosition), wallpaperPosition);

                    // Set wallpaper position
                    hResult = desktopWallpaper.SetPosition(wallpaperPositionValue);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write info to console
                    // Console.WriteLine("Position: {0}", wallpaperPositionValue);

                    // Return hResult
                    return hResult;
                }

                // <summary>
                //     Sets the background color.
                // </summary>
                public static HRESULT SetBackgroundColor(uint color) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    HRESULT hResult;

                    // Set background color
                    hResult = desktopWallpaper.SetBackgroundColor(color);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write info to console
                    Console.WriteLine("BackgroundColor: {0}", color);

                    // Return hResult
                    return hResult;
                }

                // <summary>
                //     Sets the wallpaper state to enabled or disabled.
                //     !! Not Working Yet !! If someone has a solution please submit a pull request.
                // </summary>
                public static HRESULT EnableWallpaper(bool enable) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    HRESULT hResult;

                    // Set background color
                    hResult = desktopWallpaper.Enable(enable);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write info to console
                    Console.WriteLine("Enable wallpaper: {0}", enable);

                    // Return hResult
                    return hResult;
                }

                // <summary>
                //     Sets the wallpaper slideshow image shuffle and speed.
                //     !! Not Working Yet !! If someone has a solution please submit a pull request.
                // </summary>
                public static HRESULT SetSlideshowOptions(SlideshowOptions slideshowOptions, uint slideshowTick) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    HRESULT hResult;

                    // Aet slideshow options enum number value
                    var slideshowOptionsValue = SlideshowOptions.EnableShuffle;

                    // Set slideshow options
                    hResult = desktopWallpaper.SetSlideshowOptions(slideshowOptionsValue, slideshowTick);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write info to console
                    Console.WriteLine("Set slideshow options:\nShuffleImages: {0}\nIntervalInSeconds: {1}", slideshowOptions, slideshowTick);

                    // Return hResult
                    return hResult;
                }

                // <summary>
                //     Switches the wallpaper on a specified monitor to the next image in the slideshow.
                // </summary>
                public static HRESULT AdvanceSlideshow(uint monitorIndex, string slideshowDirection) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    HRESULT hResult;

                    // Get monitor ID
                    string monitorID = MonitorCommand.GetMonitorID(monitorIndex);

                    // Get slideshow direction enum number value
                    SlideshowDirection slideshowDirectionValue = (SlideshowDirection)Enum.Parse(typeof(SlideshowDirection), slideshowDirection);

                    // Advance slideshow
                    hResult = desktopWallpaper.AdvanceSlideshow(monitorID, slideshowDirectionValue);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write info to console
                    Console.WriteLine("Advance slideshow:\nMonitorIndex: {0}\nMonitorID: {1}\nSlideshowDirection: {2}", monitorIndex, monitorID, slideshowDirection);

                    // Return hResult
                    return hResult;
                }

                // <summary>
                //     Sets the wallpaper slideshow image source folder path.
                // </summary>
                public static HRESULT SetSlideshowPath(string path) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    HRESULT hResult;
                    IShellItem pShellItem = null;
                    IShellItemArray pShellItemArray = null;

                    // Create shell item object
                    hResult = FileSystemCommand.SHCreateItemFromParsingName(path, IntPtr.Zero, typeof(IShellItem).GUID, out pShellItem);

                    // Create shell item object array
                    hResult = FileSystemCommand.SHCreateShellItemArrayFromShellItem(pShellItem, typeof(IShellItemArray).GUID, out pShellItemArray);

                    // Set slideshow folder
                    desktopWallpaper.SetSlideshow(pShellItemArray);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Return hResult
                    return hResult;
                }
            }

            // <summary>
            //     Performs file system operations.
            // </summary>
            public class FileSystemCommand {

                [DllImport("Shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
                public static extern IntPtr ILCreateFromPath([In, MarshalAs(UnmanagedType.LPWStr)] string pszPath);

                [DllImport("Shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
                public static extern HRESULT SHCreateShellItemArrayFromIDLists(uint cidl, [In, MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 0)] IntPtr[] rgpidl, out IShellItemArray ppsiItemArray);

                [DllImport("Shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
                public static extern HRESULT SHCreateItemFromParsingName(string pszPath, IntPtr pbc, [In, MarshalAs(UnmanagedType.LPStruct)] Guid riid, out IShellItem ppv);

                [DllImport("Shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
                public static extern HRESULT SHCreateShellItemArrayFromShellItem(IShellItem psi, [In, MarshalAs(UnmanagedType.LPStruct)] Guid riid, out IShellItemArray ppv);
            }
        }
'@
        #endregion
    }
    Process {
        Try {
            $Win32API = Add-Type -TypeDefinition $TypeDefinition -ReferencedAssemblies $ReferencedAssemblies -ErrorAction 'Stop'
            Write-Verbose -Message 'Successfully imported Win32 IDesktop API.'
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {
            Write-Output -InputObject $Win32API
        }
    }
    End {
    }
}
#endregion