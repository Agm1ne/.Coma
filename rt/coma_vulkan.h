/* coma_vulkan.h — Declaraciones manuales de Vulkan (sin <vulkan/vulkan.h>)
   Para cross-compilación desde Windows a Linux. */

#ifndef COMA_VULKAN_H
#define COMA_VULKAN_H

#include <stdint.h>
#include <stddef.h>

/* Opaque handles */
typedef void* VkInstance;
typedef void* VkPhysicalDevice;
typedef void* VkDevice;
typedef void* VkQueue;
typedef void* VkCommandPool;
typedef void* VkCommandBuffer;
typedef void* VkPipeline;
typedef void* VkPipelineLayout;
typedef void* VkDescriptorSetLayout;
typedef void* VkDescriptorSet;
typedef void* VkBuffer;
typedef void* VkDeviceMemory;
typedef void* VkShaderModule;
typedef void* VkFence;
typedef void* VkSemaphore;
typedef void* VkSurfaceKHR;
typedef void* VkSwapchainKHR;
typedef void* VkImage;
typedef void* VkImageView;
typedef void* VkFramebuffer;
typedef void* VkRenderPass;
typedef void* VkDescriptorPool;

typedef uint32_t VkResult;
typedef uint32_t VkFlags;
typedef uint32_t VkBool32;
typedef uint64_t VkDeviceSize;

#define VK_NULL_HANDLE 0
#define VK_SUCCESS 0
#define VK_FALSE 0
#define VK_TRUE 1

#define VK_STRUCTURE_TYPE_APPLICATION_INFO 0
#define VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO 1
#define VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO 3
#define VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO 4
#define VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO 18
#define VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO 5
#define VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO 24
#define VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO 39
#define VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO 52
#define VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO 55
#define VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO 67
#define VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO 40
#define VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO 10
#define VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO 11
#define VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO 12
#define VK_STRUCTURE_TYPE_SUBMIT_INFO 14
#define VK_STRUCTURE_TYPE_FENCE_CREATE_INFO 29
#define VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET 59
#define VK_STRUCTURE_TYPE_DESCRIPTOR_BUFFER_INFO 61
#define VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO 60
#define VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO 58
#define VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR 1000004000
#define VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR 1000000000
#define VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER 26
#define VK_STRUCTURE_TYPE_PRESENT_INFO_KHR 1000001000
#define VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO 28

#define VK_SHADER_STAGE_COMPUTE_BIT 0x00000020u
#define VK_SHADER_STAGE_GRAPHICS_BIT 0x00000001u
#define VK_DESCRIPTOR_TYPE_STORAGE_BUFFER 4
#define VK_BUFFER_USAGE_STORAGE_BUFFER_BIT 0x00000400u
#define VK_BUFFER_USAGE_TRANSFER_DST_BIT 0x00000400u
#define VK_SHARING_MODE_EXCLUSIVE 0
#define VK_COMMAND_BUFFER_LEVEL_PRIMARY 0
#define VK_PIPELINE_BIND_POINT_COMPUTE 0
#define VK_PIPELINE_BIND_POINT_GRAPHICS 0
#define VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT 0x00000001u
#define VK_QUEUE_COMPUTE_BIT 0x00000002u
#define VK_QUEUE_GRAPHICS_BIT 0x00000001u
#define VK_API_VERSION_1_0 4194304u
#define VK_WHOLE_SIZE (~0ULL)
#define VK_QUEUE_FAMILY_IGNORED 0xFFFFFFFFu

#define VK_IMAGE_TYPE_2D 1
#define VK_FORMAT_B8G8R8A8_UNORM 83
#define VK_SAMPLE_COUNT_1_BIT 0x00000001u
#define VK_IMAGE_TILING_LINEAR 0
#define VK_IMAGE_USAGE_TRANSFER_DST_BIT 0x00000400u
#define VK_IMAGE_USAGE_SAMPLED_BIT 0x00000020u
#define VK_IMAGE_LAYOUT_UNDEFINED 0
#define VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL 3
#define VK_IMAGE_LAYOUT_PRESENT_SRC_KHR 1000001002
#define VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT 0x00000001u
#define VK_PIPELINE_STAGE_TRANSFER_BIT 0x00000008u
#define VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT 0x00000010u
#define VK_ACCESS_TRANSFER_WRITE_BIT 0x00000010u
#define VK_ACCESS_MEMORY_READ_BIT 0x00000200u
#define VK_IMAGE_ASPECT_COLOR_BIT 0x00000001u

#define VK_MAKE_VERSION(major, minor, patch) ((((major) << 22) | ((minor) << 12) | (patch)))

typedef void (*PFN_vkVoidFunction)(void);

/* Function pointer types - special: return function pointers */
typedef PFN_vkVoidFunction (*PFN_vkGetInstanceProcAddr)(VkInstance, const char*);
typedef PFN_vkVoidFunction (*PFN_vkGetDeviceProcAddr)(VkDevice, const char*);

/* Function pointer types - VkResult-returning functions */
typedef VkResult (*PFN_vkCreateInstance)(const void*, const void*, VkInstance*);
typedef VkResult (*PFN_vkEnumeratePhysicalDevices)(VkInstance, uint32_t*, VkPhysicalDevice*);
typedef VkResult (*PFN_vkCreateDevice)(VkPhysicalDevice, const void*, const void*, VkDevice*);
typedef VkResult (*PFN_vkCreateBuffer)(VkDevice, const void*, const void*, VkBuffer*);
typedef VkResult (*PFN_vkAllocateMemory)(VkDevice, const void*, const void*, VkDeviceMemory*);
typedef VkResult (*PFN_vkBindBufferMemory)(VkDevice, VkBuffer, VkDeviceMemory, VkDeviceSize);
typedef VkResult (*PFN_vkCreateShaderModule)(VkDevice, const void*, const void*, VkShaderModule*);
typedef VkResult (*PFN_vkCreateDescriptorSetLayout)(VkDevice, const void*, const void*, VkDescriptorSetLayout*);
typedef VkResult (*PFN_vkCreatePipelineLayout)(VkDevice, const void*, const void*, VkPipelineLayout*);
typedef VkResult (*PFN_vkCreateComputePipelines)(VkDevice, void*, uint32_t, const void*, const void*, VkPipeline*);
typedef VkResult (*PFN_vkCreateCommandPool)(VkDevice, const void*, const void*, VkCommandPool*);
typedef VkResult (*PFN_vkAllocateCommandBuffers)(VkDevice, const void*, VkCommandBuffer*);
typedef VkResult (*PFN_vkBeginCommandBuffer)(VkCommandBuffer, const void*);
typedef VkResult (*PFN_vkEndCommandBuffer)(VkCommandBuffer);
typedef VkResult (*PFN_vkQueueSubmit)(VkQueue, uint32_t, const void*, VkFence);
typedef VkResult (*PFN_vkQueueWaitIdle)(VkQueue);
typedef VkResult (*PFN_vkDeviceWaitIdle)(VkDevice);
typedef VkResult (*PFN_vkMapMemory)(VkDevice, VkDeviceMemory, VkDeviceSize, VkDeviceSize, VkFlags, void**);
typedef VkResult (*PFN_vkCreateDescriptorPool)(VkDevice, const void*, const void*, VkDescriptorPool*);
typedef VkResult (*PFN_vkAllocateDescriptorSets)(VkDevice, const void*, VkDescriptorSet*);
typedef VkResult (*PFN_vkCreateFence)(VkDevice, const void*, const void*, VkFence*);
typedef VkResult (*PFN_vkCreateXlibSurfaceKHR)(VkInstance, const void*, const void*, VkSurfaceKHR*);
typedef VkResult (*PFN_vkCreateWin32SurfaceKHR)(VkInstance, const void*, const void*, VkSurfaceKHR*);
typedef VkResult (*PFN_vkGetPhysicalDeviceSurfaceSupportKHR)(VkPhysicalDevice, uint32_t, VkSurfaceKHR, VkBool32*);
typedef VkResult (*PFN_vkCreateSwapchainKHR)(VkDevice, const void*, const void*, VkSwapchainKHR*);
typedef VkResult (*PFN_vkGetSwapchainImagesKHR)(VkDevice, VkSwapchainKHR, uint32_t*, VkImage*);
typedef VkResult (*PFN_vkCreateImageView)(VkDevice, const void*, const void*, VkImageView*);
typedef VkResult (*PFN_vkCreateRenderPass)(VkDevice, const void*, const void*, VkRenderPass*);
typedef VkResult (*PFN_vkCreateGraphicsPipelines)(VkDevice, void*, uint32_t, const void*, const void*, VkPipeline*);
typedef VkResult (*PFN_vkCreateImage)(VkDevice, const void*, const void*, VkImage*);
typedef VkResult (*PFN_vkBindImageMemory)(VkDevice, VkImage, VkDeviceMemory, VkDeviceSize);
typedef VkResult (*PFN_vkCmdCopyBufferToImage)(VkCommandBuffer, VkBuffer, VkImage, uint32_t, const void*);
typedef VkResult (*PFN_vkCmdPipelineBarrier)(VkCommandBuffer, uint32_t, uint32_t, VkFlags, uint32_t, const void*, uint32_t, const void*, uint32_t, const void*);
typedef VkResult (*PFN_vkAcquireNextImageKHR)(VkDevice, VkSwapchainKHR, uint64_t, VkSemaphore, VkFence, uint32_t*);
typedef VkResult (*PFN_vkQueuePresentKHR)(VkQueue, const void*);
typedef VkResult (*PFN_vkCreateSemaphore)(VkDevice, const void*, const void*, VkSemaphore*);

/* Function pointer types - void-returning functions */
typedef void (*PFN_vkGetPhysicalDeviceProperties)(VkPhysicalDevice, void*);
typedef void (*PFN_vkGetPhysicalDeviceQueueFamilyProperties)(VkPhysicalDevice, uint32_t*, void*);
typedef void (*PFN_vkGetPhysicalDeviceMemoryProperties)(VkPhysicalDevice, void*);
typedef void (*PFN_vkGetDeviceQueue)(VkDevice, uint32_t, uint32_t, VkQueue*);
typedef void (*PFN_vkGetDeviceMemoryRequirements)(VkDevice, VkBuffer, void*);
typedef void (*PFN_vkFreeMemory)(VkDevice, VkDeviceMemory, const void*);
typedef void (*PFN_vkUnmapMemory)(VkDevice, VkDeviceMemory);
typedef void (*PFN_vkDestroyBuffer)(VkDevice, VkBuffer, const void*);
typedef void (*PFN_vkDestroyShaderModule)(VkDevice, VkShaderModule, const void*);
typedef void (*PFN_vkDestroyDescriptorSetLayout)(VkDevice, VkDescriptorSetLayout, const void*);
typedef void (*PFN_vkDestroyPipelineLayout)(VkDevice, VkPipelineLayout, const void*);
typedef void (*PFN_vkDestroyPipeline)(VkDevice, VkPipeline, const void*);
typedef void (*PFN_vkDestroyCommandPool)(VkDevice, VkCommandPool, const void*);
typedef void (*PFN_vkDestroyDevice)(VkDevice, const void*);
typedef void (*PFN_vkDestroyInstance)(VkInstance, const void*);
typedef void (*PFN_vkUpdateDescriptorSets)(VkDevice, uint32_t, const void*, uint32_t, const void*);
typedef void (*PFN_vkDestroyFence)(VkDevice, VkFence, const void*);
typedef void (*PFN_vkDestroySemaphore)(VkDevice, VkSemaphore, const void*);
typedef void (*PFN_vkDestroyImageView)(VkDevice, VkImageView, const void*);
typedef PFN_vkVoidFunction (*PFN_vkCreateFramebuffer)(VkDevice, VkFramebuffer, const void*);
typedef void (*PFN_vkDestroyFramebuffer)(VkDevice, VkFramebuffer, const void*);
typedef void (*PFN_vkDestroySwapchainKHR)(VkDevice, VkSwapchainKHR, const void*);
typedef void (*PFN_vkDestroySurfaceKHR)(VkInstance, VkSurfaceKHR, const void*);
typedef void (*PFN_vkDestroyImage)(VkDevice, VkImage, const void*);
typedef void (*PFN_vkCmdBindPipeline)(VkCommandBuffer, uint32_t, VkPipeline);
typedef void (*PFN_vkCmdBindDescriptorSets)(VkCommandBuffer, uint32_t, VkPipelineLayout, uint32_t, uint32_t, const VkDescriptorSet*, uint32_t, const uint32_t*);
typedef void (*PFN_vkCmdDispatch)(VkCommandBuffer, uint32_t, uint32_t, uint32_t);
typedef void (*PFN_vkCmdBeginRenderPass)(VkCommandBuffer, const void*, const void*, uint32_t);
typedef void (*PFN_vkCmdEndRenderPass)(VkCommandBuffer);
typedef void (*PFN_vkCmdDraw)(VkCommandBuffer, uint32_t, uint32_t, uint32_t, uint32_t);
typedef void (*PFN_vkCmdEndRenderPass2)(VkCommandBuffer, const void*);
typedef void (*PFN_vkDestroyRenderPass)(VkDevice, VkRenderPass, const void*);

/* Struct layouts (must match Vulkan header exactly) */
typedef struct {
    uint32_t sType;
    const void* pNext;
    const char* pApplicationName;
    uint32_t applicationVersion;
    const char* pEngineName;
    uint32_t engineVersion;
    uint32_t apiVersion;
} VkApplicationInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    const VkApplicationInfo* pApplicationInfo;
    uint32_t enabledLayerCount;
    const char* const* ppEnabledLayerNames;
    uint32_t enabledExtensionCount;
    const char* const* ppEnabledExtensionNames;
} VkInstanceCreateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    uint32_t queueFamilyIndex;
    uint32_t queueCount;
    const float* pQueuePriorities;
} VkDeviceQueueCreateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    uint32_t queueCreateInfoCount;
    const VkDeviceQueueCreateInfo* pQueueCreateInfos;
    uint32_t enabledLayerCount;
    const char* const* ppEnabledLayerNames;
    uint32_t enabledExtensionCount;
    const char* const* ppEnabledExtensionNames;
    const void* pEnabledFeatures;
} VkDeviceCreateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    uint64_t size;
    uint32_t usage;
    uint32_t sharingMode;
    uint32_t queueFamilyIndexCount;
    const uint32_t* pQueueFamilyIndices;
} VkBufferCreateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t imageType;
    uint32_t format;
    struct { uint32_t width; uint32_t height; uint32_t depth; } extent;
    uint32_t mipLevels;
    uint32_t arrayLayers;
    uint32_t samples;
    uint32_t tiling;
    uint32_t usage;
    uint32_t sharingMode;
    uint32_t queueFamilyIndexCount;
    const uint32_t* pQueueFamilyIndices;
    uint32_t initialLayout;
} VkImageCreateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    VkDeviceSize allocationSize;
    uint32_t memoryTypeIndex;
} VkMemoryAllocateInfo;

typedef struct {
    VkDeviceSize size;
    VkDeviceSize alignment;
    uint32_t memoryTypeBits;
} VkMemoryRequirements;

typedef struct {
    uint32_t queueFlags;
    uint32_t queueCount;
    uint32_t timestampValidBits;
    void* pNext;
} VkQueueFamilyProperties;

typedef struct {
    uint32_t binding;
    uint32_t descriptorType;
    uint32_t descriptorCount;
    uint32_t stageFlags;
    const void* pImmutableSamplers;
} VkDescriptorSetLayoutBinding;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    uint32_t bindingCount;
    const VkDescriptorSetLayoutBinding* pBindings;
} VkDescriptorSetLayoutCreateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    uint32_t setLayoutCount;
    const VkDescriptorSetLayout* pSetLayouts;
    uint32_t pushConstantRangeCount;
    const void* pPushConstantRanges;
} VkPipelineLayoutCreateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    uint64_t codeSize;
    const uint32_t* pCode;
} VkShaderModuleCreateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    uint32_t stage;
    void* module;
    const char* pName;
    const void* pSpecializationInfo;
} VkPipelineShaderStageCreateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    VkPipelineShaderStageCreateInfo stage;
    VkPipelineLayout layout;
    VkPipeline basePipelineHandle;
    int32_t basePipelineIndex;
} VkComputePipelineCreateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    uint32_t queueFamilyIndex;
} VkCommandPoolCreateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    VkCommandPool commandPool;
    uint32_t level;
    uint32_t commandBufferCount;
} VkCommandBufferAllocateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    const void* pInheritanceInfo;
} VkCommandBufferBeginInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t waitSemaphoreCount;
    const VkSemaphore* pWaitSemaphores;
    const uint32_t* pWaitDstStageMask;
    uint32_t commandBufferCount;
    const VkCommandBuffer* pCommandBuffers;
    uint32_t signalSemaphoreCount;
    const VkSemaphore* pSignalSemaphores;
} VkSubmitInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
} VkFenceCreateInfo;

typedef struct {
    VkBuffer buffer;
    VkDeviceSize offset;
    VkDeviceSize range;
} VkDescriptorBufferInfo;

typedef struct {
    uint32_t type;
    uint32_t descriptorCount;
} VkDescriptorPoolSize;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    uint32_t maxSets;
    uint32_t poolSizeCount;
    const VkDescriptorPoolSize* pPoolSizes;
} VkDescriptorPoolCreateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    VkDescriptorPool descriptorPool;
    uint32_t descriptorSetCount;
    const VkDescriptorSetLayout* pSetLayouts;
    VkDescriptorSet* pDescriptorSets;
} VkDescriptorSetAllocateInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    void* dpy;
    void* window;
} VkXlibSurfaceCreateInfoKHR;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
    void* hinstance;
    void* hwnd;
} VkWin32SurfaceCreateInfoKHR;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t apiVersion;
    uint32_t driverVersion;
    uint32_t vendorID;
    uint32_t deviceID;
    uint32_t deviceType;
    char deviceName[256];
    uint8_t pipelineCacheUUID[16];
} VkPhysicalDeviceProperties;

typedef struct {
    uint32_t memoryTypeCount;
    struct { uint32_t propertyFlags; } memoryTypes[32];
    uint32_t memoryHeapCount;
} VkPhysicalDeviceMemoryProperties;

typedef struct {
    void* sampler;
    void* imageView;
    uint32_t imageLayout;
} VkDescriptorImageInfo;

typedef struct {
    uint32_t sType;
    const void* pNext;
    VkDescriptorSet dstSet;
    uint32_t dstBinding;
    uint32_t dstArrayElement;
    uint32_t descriptorCount;
    uint32_t descriptorType;
    const void* pBufferInfo;
    const void* pImageInfo;
    const void* pTexelBufferView;
} VkWriteDescriptorSet;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t srcAccessMask;
    uint32_t dstAccessMask;
    uint32_t oldLayout;
    uint32_t newLayout;
    uint32_t srcQueueFamilyIndex;
    uint32_t dstQueueFamilyIndex;
    VkImage image;
    struct { uint32_t aspectMask; uint32_t baseMipLevel; uint32_t levelCount; uint32_t baseArrayLayer; uint32_t layerCount; } subresourceRange;
} VkImageMemoryBarrier;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t swapchainCount;
    const VkSwapchainKHR* pSwapchains;
    const uint32_t* pImageIndices;
    uint32_t waitSemaphoreCount;
    const VkSemaphore* pWaitSemaphores;
} VkPresentInfoKHR;

typedef struct {
    uint32_t sType;
    const void* pNext;
    uint32_t flags;
} VkSemaphoreCreateInfo;

#endif
