import { useSnackbar } from "notistack";
import { addRegPeriod, getAllRegperiods, getLatestSemesters, removeRegPeriod, updateRegPeriod } from "../API/AminAPI";
import RegPeriodForm from "../AdminComponent/RegPeriodForm";
import { formatDateTime} from "../Util/FormatDateTime";
import { useContext, useEffect, useState } from "react";
import { AdminContext } from "../Router/AdminRouter";
import TableHeader from "../Component/TableHeader";
import { FormModal } from "../AdminComponent/ModalAndAlert";
const initialRegPeriod={
    openTime:"",
    closeTime:"",
    semester:{
            id:0
    }
}
const OpeningRegPeriod=()=>{
          const {setError}=useContext(AdminContext);
          const [regPeriodData, setRegPeriodData]=useState([]);
          const[show, setShow]=useState(0); //0: not show, 1: show FormModal
          const [semesters, setSemesters]=useState([]);
          const [flag, setFlag]=useState(true);
          const { enqueueSnackbar } = useSnackbar();
          const config = {variant: '',anchorOrigin:{ horizontal: 'center' , vertical: 'bottom'}}
          const [regPeriodDTO, setRegPeriodDTO]=useState(initialRegPeriod);
          useEffect(()=>{
                getAllRegperiods().then(res=>{
                    setRegPeriodData(res.data)
                })
                .catch(err=>setError(err))
                getLatestSemesters().then(res=>{
                    setSemesters(res.data)
                })
                .catch(err=>setError(err))
          },[])
          const handleError=(err)=>{
                if(err.response.status==400){
                    config.variant="error";
                    enqueueSnackbar(err.response.data, config);
                }
                else setError(err)
          }
          const handleAddButton=(e)=>{
                    e.preventDefault();
                    setFlag(true);
                    setShow(1);
          }
          const handleSubmit=()=>{
                if(flag){
                    addRegPeriod(regPeriodDTO).then(res=>{
                        setRegPeriodData((prevData)=>{
                            const updatedData=[...prevData];
                            updatedData.push(res.data);
                            return updatedData;
                        })
                        setShow(0);
                        config.variant="success"
                        enqueueSnackbar("Thêm thành công đợt đăng kí mới", config)
                    })
                    .catch(err=>handleError(err))
                }
                else{
                        updateRegPeriod(regPeriodDTO).then(res=>{
                            setRegPeriodData((prevData)=>{
                                const updatedData=[...prevData];
                               for(let i=0;i<updatedData.length;i++){
                                    if(updatedData[i].id===res.data.id)
                                        updatedData[i]={...res.data};
                               }
                                return updatedData;
                            })
                            setShow(0);
                            config.variant="success"
                            enqueueSnackbar("Update thành công!", config)
                        })
                        .catch(err=>handleError(err))
                }
          }
          const handleDelButton=(e,id)=>{
                e.preventDefault();
                removeRegPeriod(id).then(res=>{
                    setRegPeriodData(prev=>prev.filter(data=>data.id!=id));
                    config.variant="success";
                    enqueueSnackbar("Xóa thành công đợt đăng kí", config)
                })
                .catch(err=>setError(err))
          }
          const handleModifyButton=(e,id)=>{
                e.preventDefault()
                regPeriodData.forEach((data)=>{
                    if(data.id==id) setRegPeriodDTO(data);
                })
                setFlag(false);
                setShow(1);
          }
          return(
          <>
          <div className="main-page">
                    <div className="ContentAlignment">
                              <h1>Danh sách các đợt đăng kí</h1>
                              <button  type="button" className="btn btn-success" onClick={(e)=>handleAddButton(e)}>Thêm đợt DK</button>
                    </div>
                    <div className="TableWapper border-bottom border-dark">
                        <table className="table table-hover">
                            <TableHeader data={["STT","Học kì","Thời gian BD","Thời gian KT","Action"]} />
                            <tbody>
                        {regPeriodData?.map((data, index)=> {
                                return (
                                    <tr key={index}>
                                        <th>{index+1}</th>
                                        <td>Kì {data.semester.semesterNum}, năm {data.semester.year}-{data.semester.year+1}</td>
                                        <td>{formatDateTime(data.openTime)}</td>
                                        <td>{formatDateTime(data.closeTime)}</td>
                                        <td colSpan={2}>
                                                  <button type="button" className="btn btn-danger mr-2" onClick={(e)=>handleDelButton(e,data.id)}>Delete</button>
                                                  <button type="button" className="btn btn-primary" onClick={(e)=>handleModifyButton(e, data.id)}>Modify</button>
                                        </td>
                                    </tr>
                                )
                            })}
                            </tbody>
                        </table>
                    </div>
          </div>
            {show==1&&<FormModal setShow={setShow} handleSubmit={handleSubmit} title="THÊM ĐỢT ĐĂNG KÍ"><RegPeriodForm regPeriodDTO={regPeriodDTO}  setRegPeriodDTO={setRegPeriodDTO} semesters={semesters}/></FormModal>}
          </>
          )
}
export default OpeningRegPeriod;