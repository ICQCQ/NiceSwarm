package main

import (
	"image"
	"image/color"

	"gioui.org/app"
	"gioui.org/font/gofont"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/text"
	"gioui.org/unit"
	"gioui.org/widget"
	"gioui.org/widget/material"

	"niceswarm-launcher/internal/config"
)

// Layout type shorthands.
type (
	C = layout.Context
	D = layout.Dimensions
)

var (
	colMuted     = color.NRGBA{R: 0x8a, G: 0x8a, B: 0x96, A: 0xff}
	colSecondary = color.NRGBA{R: 0x42, G: 0x45, B: 0x52, A: 0xff}
	colDisabled  = color.NRGBA{R: 0x3a, G: 0x3a, B: 0x42, A: 0xff}
)

// ui owns the Gio widgets and theme; the controller owns the app state behind them.
type ui struct {
	th      *material.Theme
	c       *controller
	dataDir string

	debug         widget.Bool
	checkBtn      widget.Clickable
	playBtn       widget.Clickable
	updateSelfBtn widget.Clickable
}

// runGUI opens the launcher window, kicks off the initial checks, and runs the Gio
// event loop until the window is closed.
func runGUI(dataDir string, cfg config.Config) error {
	w := new(app.Window)
	w.Option(
		app.Title("NiceSwarm Launcher"),
		app.Size(unit.Dp(460), unit.Dp(340)),
		app.MinSize(unit.Dp(400), unit.Dp(300)),
	)

	th := material.NewTheme()
	th.Shaper = text.NewShaper(text.WithCollection(gofont.Collection()))

	c := newController(w, dataDir, cfg)
	u := &ui{th: th, c: c, dataDir: dataDir}
	u.debug.Value = cfg.Debug

	// Initial game check (claims the worker slot) + read-only launcher self-check.
	if c.tryStart("Checking for updates…") {
		go c.checkAndUpdate(cfg.Debug)
	}
	go c.checkLauncher()

	var ops op.Ops
	for {
		switch e := w.Event().(type) {
		case app.DestroyEvent:
			return e.Err
		case app.FrameEvent:
			gtx := app.NewContext(&ops, e)
			u.handle(gtx)
			u.layout(gtx)
			e.Frame(gtx.Ops)
		}
	}
}

// handle processes widget interactions for this frame before it is laid out.
func (u *ui) handle(gtx C) {
	st := u.c.state()

	// Debug toggle: switching builds means re-checking against a different asset, so it
	// must wait until the current operation finishes. While busy, revert the flip.
	if u.debug.Update(gtx) {
		if st.busy {
			u.debug.Value = !u.debug.Value
		} else {
			_ = config.Save(u.dataDir, config.Config{Debug: u.debug.Value})
			if u.c.tryStart("Switching build…") {
				go u.c.checkAndUpdate(u.debug.Value)
			}
		}
	}
	if u.checkBtn.Clicked(gtx) {
		if u.c.tryStart("Checking for updates…") {
			go u.c.checkAndUpdate(u.debug.Value)
		}
	}
	if u.playBtn.Clicked(gtx) && st.ready {
		if u.c.tryStart("Launching…") {
			go u.c.play()
		}
	}
	if u.updateSelfBtn.Clicked(gtx) && st.launcherOutdated {
		if u.c.tryStart("Updating launcher…") {
			go u.c.updateLauncher()
		}
	}
}

func (u *ui) layout(gtx C) D {
	st := u.c.state()
	return layout.UniformInset(unit.Dp(20)).Layout(gtx, func(gtx C) D {
		return layout.Flex{Axis: layout.Vertical}.Layout(gtx,
			layout.Rigid(material.H5(u.th, "NiceSwarm").Layout),
			layout.Rigid(layout.Spacer{Height: unit.Dp(2)}.Layout),
			layout.Rigid(func(gtx C) D {
				lbl := material.Caption(u.th, "Auto-updating launcher")
				lbl.Color = colMuted
				return lbl.Layout(gtx)
			}),
			layout.Rigid(layout.Spacer{Height: unit.Dp(18)}.Layout),
			layout.Rigid(material.Body1(u.th, st.status).Layout),
			layout.Rigid(layout.Spacer{Height: unit.Dp(12)}.Layout),
			layout.Rigid(func(gtx C) D { return u.progressArea(gtx, st) }),
			layout.Rigid(layout.Spacer{Height: unit.Dp(16)}.Layout),
			layout.Rigid(func(gtx C) D { return u.buttonRow(gtx, st) }),
			layout.Rigid(layout.Spacer{Height: unit.Dp(14)}.Layout),
			layout.Rigid(func(gtx C) D {
				return material.CheckBox(u.th, &u.debug, "Debug build (verbose errors + F1 panel)").Layout(gtx)
			}),
			layout.Rigid(func(gtx C) D { return u.launcherUpdateRow(gtx, st) }),
		)
	})
}

// progressArea shows a determinate bar during a download, a spinner during an
// indeterminate phase (sidecar fetch / hashing), and nothing when idle. The row keeps
// a fixed height so the layout doesn't jump as it switches.
func (u *ui) progressArea(gtx C, st state) D {
	const h = 24
	gtx.Constraints.Min.Y = gtx.Dp(h)
	if !st.busy {
		return D{Size: image.Pt(gtx.Constraints.Max.X, gtx.Dp(h))}
	}
	if st.progress >= 0 {
		return layout.Center.Layout(gtx, material.ProgressBar(u.th, st.progress).Layout)
	}
	return layout.W.Layout(gtx, func(gtx C) D {
		gtx.Constraints = layout.Exact(image.Pt(gtx.Dp(h), gtx.Dp(h)))
		return material.Loader(u.th).Layout(gtx)
	})
}

func (u *ui) buttonRow(gtx C, st state) D {
	play := material.Button(u.th, &u.playBtn, "Play")
	if !st.ready || st.busy {
		play.Background = colDisabled
	}
	check := material.Button(u.th, &u.checkBtn, "Check for Updates")
	check.Background = colSecondary
	if st.busy {
		check.Background = colDisabled
	}
	return layout.Flex{Axis: layout.Horizontal}.Layout(gtx,
		layout.Rigid(play.Layout),
		layout.Rigid(layout.Spacer{Width: unit.Dp(10)}.Layout),
		layout.Rigid(check.Layout),
	)
}

// launcherUpdateRow renders the "newer launcher available" notice + button, or nothing
// when the launcher is current.
func (u *ui) launcherUpdateRow(gtx C, st state) D {
	if !st.launcherOutdated {
		return D{}
	}
	return layout.Inset{Top: unit.Dp(16)}.Layout(gtx, func(gtx C) D {
		return layout.Flex{Axis: layout.Vertical}.Layout(gtx,
			layout.Rigid(func(gtx C) D {
				lbl := material.Caption(u.th, "A newer launcher is available.")
				lbl.Color = colMuted
				return lbl.Layout(gtx)
			}),
			layout.Rigid(layout.Spacer{Height: unit.Dp(6)}.Layout),
			layout.Rigid(func(gtx C) D {
				b := material.Button(u.th, &u.updateSelfBtn, "Update Launcher")
				b.Background = colSecondary
				if st.busy {
					b.Background = colDisabled
				}
				return b.Layout(gtx)
			}),
		)
	})
}
