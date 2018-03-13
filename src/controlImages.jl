using Images, Gtk, Reactive, GtkReactive, ImageView
n = 100#1024
img1 = reshape(linspace(Gray{N0f16}(0), Gray{N0f16}(1), n^2), n, n)
img2 = reshape(linspace(Gray{N0f16}(0), Gray{N0f16}(1), n^2), n, n)'
img = colorview(RGB, img1, img1, img2)
g = imshow(img)


img1 .= rand(Gray{N0f16}, n,n)

img1 .= reshape(linspace(Gray{N0f16}(0), Gray{N0f16}(1), n^2), n, n)

a = value(g["roi"]["image roi"])

push!(g["roi"]["redraw"], nothing)


canvas = g["gui"]["canvas"]
s1 = slider(linspace(0,1,2^16), value=1)
s2 = slider(linspace(0,1,2^16), value=1)
img1tmp = similar(img1)
img2tmp = similar(img2)

foreach(s1, s2, init = nothing) do m1, m2
    img1tmp .= min.(img1, m1)
    img2tmp .= min.(img2, m2)
    imshow(canvas, colorview(RGB, img1tmp, img1tmp, img2tmp))
    nothing
end

push!(g["gui"]["vbox"], s1, s2)

showall(g["gui"]["window"])

zr, slicedata = roi(img1)
gd = imshow_gui((n, n), slicedata)
imshow(gd["frame"][1], gd["canvas"][1,1], img1, nothing, zr, slicedata)
imshow(gd["frame"][2], gd["canvas"][1,2], img2, nothing, zr, slicedata)
showall(gd["window"])


gd = imshow_gui((200, 200), slicedata, (1,2))
imshow(gd["frame"][1,1], gd["canvas"][1,1], img1, nothing, zr, slicedata)
imshow(gd["frame"][1,2], gd["canvas"][1,2], mriseg, nothing, zr, slicedata)
showall(gd["window"])

using ImageView, GtkReactive, TestImages, Colors
# Prepare the data
n = 200
mri = reshape(linspace(Gray{N0f16}(0), Gray{N0f16}(1), n^2), n, n)
mriseg = reshape(linspace(Gray{N0f16}(0), Gray{N0f16}(1), n^2), n, n)'
zr, slicedata = roi(mri, (1,2))
gd = imshow_gui((200, 200), slicedata, (1,2))
imshow(gd["frame"][1,1], gd["canvas"][1,1], mri, nothing, zr, slicedata)
imshow(gd["frame"][1,2], gd["canvas"][1,2], mriseg, nothing, zr, slicedata)
showall(gd["window"])
