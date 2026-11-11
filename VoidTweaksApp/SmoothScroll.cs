using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Animation;

namespace VoidTweaks;

// Attach local:SmoothScroll.Enabled="True" to a ScrollViewer for animated, pixel-smooth
// mouse-wheel scrolling (instead of the default chunky line jumps).
public static class SmoothScroll
{
    public static bool GetEnabled(DependencyObject o) => (bool)o.GetValue(EnabledProperty);
    public static void SetEnabled(DependencyObject o, bool v) => o.SetValue(EnabledProperty, v);
    public static readonly DependencyProperty EnabledProperty =
        DependencyProperty.RegisterAttached("Enabled", typeof(bool), typeof(SmoothScroll), new PropertyMetadata(false, OnEnabled));

    // Animated offset (set by the animation, pushes the scroll position).
    private static readonly DependencyProperty OffsetProperty =
        DependencyProperty.RegisterAttached("Offset", typeof(double), typeof(SmoothScroll), new PropertyMetadata(0.0, OnOffset));
    // Where we are animating TO (not animated itself, so wheel ticks compose cleanly).
    private static readonly DependencyProperty TargetProperty =
        DependencyProperty.RegisterAttached("Target", typeof(double), typeof(SmoothScroll), new PropertyMetadata(double.NaN));

    private static void OnEnabled(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is not ScrollViewer sv) return;
        if ((bool)e.NewValue)
        {
            sv.PreviewMouseWheel += OnWheel;
            // keep target synced when the user drags the scrollbar or content changes
            sv.ScrollChanged += (_, ev) => { if (ev.VerticalChange != 0 && IsNaN(sv)) sv.SetValue(TargetProperty, sv.VerticalOffset); };
        }
        else sv.PreviewMouseWheel -= OnWheel;
    }

    private static bool IsNaN(ScrollViewer sv) => double.IsNaN((double)sv.GetValue(TargetProperty));

    private static void OnWheel(object sender, System.Windows.Input.MouseWheelEventArgs e)
    {
        if (sender is not ScrollViewer sv || sv.ScrollableHeight <= 0) return;
        e.Handled = true;
        double target = (double)sv.GetValue(TargetProperty);
        if (double.IsNaN(target)) target = sv.VerticalOffset;
        target = Math.Max(0, Math.Min(sv.ScrollableHeight, target - e.Delta));
        sv.SetValue(TargetProperty, target);
        var anim = new DoubleAnimation(target, TimeSpan.FromMilliseconds(260))
        {
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut }
        };
        sv.BeginAnimation(OffsetProperty, anim, HandoffBehavior.SnapshotAndReplace);
    }

    private static void OnOffset(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is ScrollViewer sv) sv.ScrollToVerticalOffset((double)e.NewValue);
    }
}
