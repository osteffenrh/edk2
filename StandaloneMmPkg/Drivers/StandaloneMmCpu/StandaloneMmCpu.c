/** @file

  Copyright (c) 2008 - 2009, Apple Inc. All rights reserved.<BR>
  Copyright (c) 2016 HP Development Company, L.P.
  Copyright (c) 2016 - 2024, Arm Limited. All rights reserved.
  Copyright (c) 2023, Ventana Micro System Inc. All rights reserved.

  SPDX-License-Identifier: BSD-2-Clause-Patent

**/

#include <Base.h>
#include <Pi/PiMmCis.h>
#include <Library/DebugLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/HobLib.h>

#include <Protocol/DebugSupport.h> // for EFI_SYSTEM_CONTEXT

#include <Guid/ZeroGuid.h>
#include <Guid/MmramMemoryReserve.h>

#include <StandaloneMmCpu.h>

// GUID to identify HOB with whereabouts of communication buffer with Normal
// World
extern EFI_GUID  gEfiStandaloneMmNonSecureBufferGuid;

//
// mPiMmCpuDriverEpProtocol for Cpu driver entry point to handle
// mm communication event.
//
extern EDKII_PI_MM_CPU_DRIVER_EP_PROTOCOL  mPiMmCpuDriverEpProtocol;

//
// Private copy of the MM system table for future use
//
EFI_MM_SYSTEM_TABLE  *mMmst = NULL;

//
// Globals used to initialize the protocol
//
STATIC EFI_HANDLE  mMmCpuHandle = NULL;

/** Returns the HOB data for the matching HOB GUID.

  @param  [in]  HobList  Pointer to the HOB list.
  @param  [in]  HobGuid  The GUID for the HOB.
  @param  [out] HobData  Pointer to the HOB data.

  @retval  EFI_SUCCESS            The function completed successfully.
  @retval  EFI_INVALID_PARAMETER  Invalid parameter.
  @retval  EFI_NOT_FOUND          Could not find HOB with matching GUID.
**/
EFI_STATUS
GetGuidedHobData (
  IN  VOID            *HobList,
  IN  CONST EFI_GUID  *HobGuid,
  OUT VOID            **HobData
  )
{
  EFI_HOB_GUID_TYPE  *Hob;

  if ((HobList == NULL) || (HobGuid == NULL) || (HobData == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  Hob = GetNextGuidHob (HobGuid, HobList);
  if (Hob == NULL) {
    return EFI_NOT_FOUND;
  }

  *HobData = GET_GUID_HOB_DATA (Hob);
  if (*HobData == NULL) {
    return EFI_NOT_FOUND;
  }

  return EFI_SUCCESS;
}

/** Entry point for the Standalone MM CPU driver.

  @param  [in]  ImageHandle   Unused. Not actual image handle.
  @param  [in]  SystemTable   Pointer to MM System table.

  @retval  EFI_SUCCESS            The function completed successfully.
  @retval  EFI_INVALID_PARAMETER  Invalid parameter.
  @retval  EFI_OUT_OF_RESOURCES   Out of resources.
  @retval  EFI_NOT_FOUND          Failed to find the HOB for the CPU
                                  driver endpoint descriptor.
**/
EFI_STATUS
StandaloneMmCpuInitialize (
  IN EFI_HANDLE           ImageHandle,   // not actual imagehandle
  IN EFI_MM_SYSTEM_TABLE  *SystemTable   // not actual systemtable
  )
{
  EFI_CONFIGURATION_TABLE  *ConfigurationTable;
  MP_INFORMATION_HOB_DATA  *MpInformationHobData;
  EFI_STATUS               Status;
  EFI_HANDLE               DispatchHandle;
  UINT32                   MpInfoSize;
  UINTN                    Index;
  UINTN                    ArraySize;
  VOID                     *HobStart;

  ASSERT (SystemTable != NULL);
  mMmst = SystemTable;

  // publish the MM config protocol so the MM core can register its entry point
  Status = mMmst->MmInstallProtocolInterface (
                    &mMmCpuHandle,
                    &gEfiMmConfigurationProtocolGuid,
                    EFI_NATIVE_INTERFACE,
                    &mMmConfig
                    );
  if (EFI_ERROR (Status)) {
    return Status;
  }

  // Install  entry point of this CPU driver to allow
  // the entry point driver to be invoked upon receipt of an event in
  // DelegatedEventLoop.
  Status = mMmst->MmInstallProtocolInterface (
                    &mMmCpuHandle,
                    &gEdkiiPiMmCpuDriverEpProtocolGuid,
                    EFI_NATIVE_INTERFACE,
                    &mPiMmCpuDriverEpProtocol
                    );
  if (EFI_ERROR (Status)) {
    return Status;
  }

  // register the root MMI handler
  Status = mMmst->MmiHandlerRegister (
                    PiMmCpuTpFwRootMmiHandler,
                    NULL,
                    &DispatchHandle
                    );
  if (EFI_ERROR (Status)) {
    return Status;
  }

  // Retrieve the Hoblist from the MMST to extract the details of the NS
  // communication buffer that has been reserved for StandaloneMmPkg
  ConfigurationTable = mMmst->MmConfigurationTable;
  for (Index = 0; Index < mMmst->NumberOfTableEntries; Index++) {
    if (CompareGuid (&gEfiHobListGuid, &(ConfigurationTable[Index].VendorGuid))) {
      break;
    }
  }

  // Bail out if the Hoblist could not be found
  if (Index >= mMmst->NumberOfTableEntries) {
    DEBUG ((DEBUG_ERROR, "Hoblist not found - 0x%x\n", Index));
    return EFI_OUT_OF_RESOURCES;
  }

  HobStart = ConfigurationTable[Index].VendorTable;

  //
  // Extract the MP information from the Hoblist
  //
  Status = GetGuidedHobData (
             HobStart,
             &gMpInformationHobGuid,
             (VOID **)&MpInformationHobData
             );
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "MpInformationHob extraction failed - 0x%x\n", Status));
    return Status;
  }

  //
  // Allocate memory for the MP information and copy over the MP information
  // passed by Trusted Firmware. Use the number of processors passed in the HOB
  // to copy the processor information
  //
  MpInfoSize = sizeof (MP_INFORMATION_HOB_DATA) +
               (sizeof (EFI_PROCESSOR_INFORMATION) *
                MpInformationHobData->NumberOfProcessors);
  Status = mMmst->MmAllocatePool (
                    EfiRuntimeServicesData,
                    MpInfoSize,
                    (VOID **)&mMpInformationHobData
                    );
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "mMpInformationHobData mem alloc failed - 0x%x\n", Status));
    return Status;
  }

  CopyMem (mMpInformationHobData, MpInformationHobData, MpInfoSize);

  // Print MP information
  DEBUG ((
    DEBUG_INFO,
    "mMpInformationHobData: 0x%016lx - 0x%lx\n",
    mMpInformationHobData->NumberOfProcessors,
    mMpInformationHobData->NumberOfEnabledProcessors
    ));
  for (Index = 0; Index < mMpInformationHobData->NumberOfProcessors; Index++) {
    DEBUG ((
      DEBUG_INFO,
      "mMpInformationHobData[0x%lx]: %d, %d, %d\n",
      mMpInformationHobData->ProcessorInfoBuffer[Index].ProcessorId,
      mMpInformationHobData->ProcessorInfoBuffer[Index].Location.Package,
      mMpInformationHobData->ProcessorInfoBuffer[Index].Location.Core,
      mMpInformationHobData->ProcessorInfoBuffer[Index].Location.Thread
      ));
  }

  //
  // Allocate memory for a table to hold pointers to a
  // EFI_MM_COMMUNICATE_HEADER for each CPU
  //
  ArraySize = sizeof (EFI_MM_COMMUNICATE_HEADER *) *
              mMpInformationHobData->NumberOfEnabledProcessors;
  Status = mMmst->MmAllocatePool (
                    EfiRuntimeServicesData,
                    ArraySize,
                    (VOID **)&PerCpuGuidedEventContext
                    );
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "PerCpuGuidedEventContext mem alloc failed - 0x%x\n", Status));
    return Status;
  }

  return Status;
}
