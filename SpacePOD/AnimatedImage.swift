import Combine
import SwiftUI

struct AnimatedImage: View {
  let image: UIImage

  @State var index = 0
  @State var timer: AnyCancellable?

  var body: some View {
    if let frames = image.images, frames.count > 1, index < frames.count {
      Image(uiImage: frames[index])
        .onAppear {
          timer = Timer.publish(every: image.duration / Double(frames.count), on: .main, in: .default)
            .autoconnect()
            .sink { _ in
              index = (index + 1) % frames.count
            }
        }
        .onDisappear {
          timer = nil
        }
    } else {
      Image(uiImage: image)
    }
  }
}

struct AnimatedImage_Previews: PreviewProvider {
  static var previews: some View {
    let img = UIImage.animatedImage(
      with: [
        UIImage(systemName: "1.circle")!,
        UIImage(systemName: "2.circle")!,
        UIImage(systemName: "3.circle")!,
        UIImage(systemName: "4.circle")!,
      ],
      duration: 2)!
    AnimatedImage(image: img)
      .background(Color.white)
  }
}
