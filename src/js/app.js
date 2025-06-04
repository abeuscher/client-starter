var siteSettings = {
  imagePath: "/wp-content/themes/wcg/images/",
  breakpoints: {
    xs: 0,
    s: 641,
    m: 1025,
    l: 1321,
    xl: 1921,
  },
};

window.addEventListener("load", function () {
  activateImages();
});

function activateImages() {
  // Helper to check if element is valid
  const isElement = (el) => el instanceof Element;
  
  // Helper to create responsive image element
  const createResponsiveImage = (imageObj, altText = '') => {
    // WordPress default sizes (if available)
    const sizes = imageObj.sizes || {};
    const {
      thumbnail,      // 150x150
      medium,         // 300x300
      medium_large,   // 768xAuto
      large,          // 1024x1024
      full           // Original size
    } = sizes;
    
    // Fallback to original URL if no sizes available
    const fallbackUrl = imageObj.url || full?.url || large?.url;
    
    // If we don't have multiple sizes, return a simple img
    if (!sizes || Object.keys(sizes).length === 0) {
      const img = document.createElement('img');
      img.src = fallbackUrl;
      img.alt = altText;
      return img;
    }
    
    // Create picture element for art direction
    const picture = document.createElement('picture');
    
    // Add sources for different viewport sizes
    // Using WordPress's typical responsive breakpoints
    const sourceConfigs = [
      { media: '(max-width: 480px)', size: 'thumbnail' },
      { media: '(max-width: 768px)', size: 'medium' },
      { media: '(max-width: 1024px)', size: 'medium_large' },
      { media: '(min-width: 1025px)', size: 'large' }
    ];
    
    sourceConfigs.forEach(config => {
      if (sizes[config.size]) {
        const source = document.createElement('source');
        source.media = config.media;
        source.srcset = sizes[config.size].url || sizes[config.size];
        picture.appendChild(source);
      }
    });
    
    // Fallback img element
    const img = document.createElement('img');
    img.src = fallbackUrl;
    img.alt = altText;
    
    // Generate srcset for the img element
    const srcsetArray = [];
    Object.entries(sizes).forEach(([sizeName, sizeData]) => {
      if (sizeData.url && sizeData.width) {
        srcsetArray.push(`${sizeData.url} ${sizeData.width}w`);
      } else if (typeof sizeData === 'string') {
        // Handle simple URL strings
        const width = getWidthFromSizeName(sizeName);
        if (width) {
          srcsetArray.push(`${sizeData} ${width}w`);
        }
      }
    });
    
    if (srcsetArray.length > 0) {
      img.srcset = srcsetArray.join(', ');
      // Responsive sizes attribute
      img.sizes = '(max-width: 480px) 480px, (max-width: 768px) 768px, (max-width: 1024px) 1024px, 100vw';
    }
    
    picture.appendChild(img);
    return picture;
  };
  
  // Helper to get approximate width from WordPress size name
  const getWidthFromSizeName = (sizeName) => {
    const widthMap = {
      'thumbnail': 150,
      'medium': 300,
      'medium_large': 768,
      'large': 1024,
      'full': 2048 // Assuming a reasonable max width
    };
    return widthMap[sizeName] || null;
  };
  
  // Process elements with data-bg-object
  const backgroundObjects = document.querySelectorAll('[data-bg-object]');
  backgroundObjects.forEach(element => {
    if (!isElement(element)) return;
    
    try {
      const imageObj = JSON.parse(element.getAttribute('data-bg-object'));
      const altText = element.getAttribute('data-alt') || '';
      
      // Option 1: Replace background with img element
      if (element.hasAttribute('data-replace-with-img')) {
        const responsiveImg = createResponsiveImage(imageObj, altText);
        element.parentNode.replaceChild(responsiveImg, element);
      }
      // Option 2: Insert img element inside
      else if (element.hasAttribute('data-insert-img')) {
        const responsiveImg = createResponsiveImage(imageObj, altText);
        element.innerHTML = ''; // Clear existing content
        element.appendChild(responsiveImg);
      }
      // Option 3: Keep as background but use appropriate size
      else {
        // Use different sizes for different viewport widths
        const setResponsiveBackground = () => {
          const width = window.innerWidth;
          let selectedSize = 'full';
          
          if (width <= 480) selectedSize = 'thumbnail';
          else if (width <= 768) selectedSize = 'medium';
          else if (width <= 1024) selectedSize = 'medium_large';
          else selectedSize = 'large';
          
          const url = imageObj.sizes?.[selectedSize]?.url || 
                     imageObj.sizes?.[selectedSize] || 
                     imageObj.url;
          
          element.style.backgroundImage = `url('${url}')`;
        };
        
        // Set initial background
        setResponsiveBackground();
        
        // Update on resize (debounced)
        let resizeTimer;
        window.addEventListener('resize', () => {
          clearTimeout(resizeTimer);
          resizeTimer = setTimeout(setResponsiveBackground, 250);
        });
      }
    } catch (e) {
      console.error('Error parsing image object:', e);
    }
  });
  
  // Process simple data-bg elements
  const backgroundImages = document.querySelectorAll('[data-bg]');
  backgroundImages.forEach(element => {
    if (!isElement(element)) return;
    
    const bgUrl = element.getAttribute('data-bg');
    const fullUrl = bgUrl.includes('http') 
      ? bgUrl 
      : `${siteSettings.imagePath}${bgUrl}`;
    
    element.style.backgroundImage = `url('${fullUrl}')`;
  });
}

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', activateImages);

// Example usage:
/*
<!-- Replace element with responsive image -->
<div data-bg-object='{"url":"image.jpg","sizes":{"thumbnail":"thumb.jpg","medium":"med.jpg"}}' 
     data-replace-with-img 
     data-alt="Description"></div>

<!-- Insert responsive image inside element -->
<div data-bg-object='{"url":"image.jpg","sizes":{"thumbnail":"thumb.jpg","medium":"med.jpg"}}' 
     data-insert-img></div>

<!-- Keep as responsive background (default) -->
<div data-bg-object='{"url":"image.jpg","sizes":{"thumbnail":"thumb.jpg","medium":"med.jpg"}}'></div>

<!-- Simple background -->
<div data-bg="path/to/image.jpg"></div>
*/
